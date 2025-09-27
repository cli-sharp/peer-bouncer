import SwiftUI

struct ContentView: View {
    @State private var inputText = ""
    @State private var validEntries: [BlockEntry] = []
    @State private var invalidEntries: [String] = []
    
    @State private var filePath: String? = nil
    @State private var urlString: String = ""
    @State private var isDownloading = false
    @State private var downloadError: String? = nil
    
    var body: some View {
        VStack {
            Text("Blocklist Uploader Prototype")
                .font(.title)
                .padding()
            
            HStack {
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 150)
                
                VStack(alignment: .leading, spacing: 12) {
                    Button("Parse Text") {
                        parseList(from: inputText)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Load File…") {
                        openFile()
                    }
                    .buttonStyle(.bordered)
                    
                    if let path = filePath {
                        Text("Loaded: \(path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Divider()
                    
                    TextField("Paste blocklist URL…", text: $urlString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 260)
                    
                    Button("Download & Parse") {
                        downloadAndParse()
                    }
                    .disabled(urlString.isEmpty || isDownloading)
                    .buttonStyle(.bordered)
                    
                    if isDownloading {
                        ProgressView().scaleEffect(0.6)
                    }
                    
                    if let err = downloadError {
                        Text("Error: \(err)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Valid Entries: \(validEntries.count)")
                        .font(.headline)
                    List(validEntries) { entry in
                        HStack {
                            Text(entry.normalized)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(entry.kind == .ipv4 ? "IPv4" : "IPv6")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Invalid Lines: \(invalidEntries.count)")
                        .font(.headline)
                    List(invalidEntries, id: \.self) { line in
                        Text(line)
                            .foregroundColor(.red)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(minWidth: 900, minHeight: 600)
    }
    
    private func parseList(from text: String) {
        let result = BlocklistParser.parseBlocklistText(text)
        validEntries = result.entries.map {
            BlockEntry(raw: $0.raw, normalized: $0.normalized, kind: $0.kind)
        }
        invalidEntries = result.invalidLines
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = nil // allow any extension
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                var data = try Data(contentsOf: url)
                
                // Detect gzip by extension OR magic bytes
                let isGzip = url.pathExtension.lowercased() == "gz" ||
                             (data.prefix(2) == Data([0x1f, 0x8b]))
                
                if isGzip, let decompressed = data.gunzipped() {
                    data = decompressed
                }
                
                guard let content = String(data: data, encoding: .utf8) else {
                    filePath = "Error: invalid encoding"
                    return
                }
                
                inputText = content
                filePath = url.lastPathComponent
                parseList(from: content)
                
            } catch {
                filePath = "Error reading file: \(error.localizedDescription)"
            }
        }
    }

    
    private func downloadAndParse() {
        guard let url = URL(string: urlString) else {
            downloadError = "Invalid URL"
            return
        }
        
        isDownloading = true
        downloadError = nil
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isDownloading = false
                if let error = error {
                    downloadError = error.localizedDescription
                    return
                }
                guard var data = data else {
                    downloadError = "No data received"
                    return
                }
                
                let test = data.prefix(2)
                
                // Check if it's gzip (by extension or header)
                let isGzip = url.pathExtension.lowercased() == "gz" ||
                             (data.prefix(2) == Data([0x1f, 0x8b]))
                
                if isGzip, let decompressed = data.gunzipped() {
                    data = decompressed
                }
                
                guard let text = String(data: data, encoding: .utf8) else {
                    downloadError = "Invalid file encoding"
                    return
                }
                
                inputText = text
                filePath = url.lastPathComponent
                parseList(from: text)
            }
        }.resume()
    }

}

