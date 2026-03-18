import Foundation

enum FileMoveError: LocalizedError {
    case fileNotFound(String)
    case destinationNotWritable(String)
    case moveError(String, String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File không tồn tại: \(path)"
        case .destinationNotWritable(let path):
            return "Không có quyền ghi vào: \(path)"
        case .moveError(let file, let error):
            return "Lỗi di chuyển \(file): \(error)"
        }
    }
}

class FileMover {
    private let fileManager = FileManager.default

    func moveFiles(_ sources: [String], to destination: String) -> Result<Int, FileMoveError> {
        // Verify destination is writable
        guard fileManager.isWritableFile(atPath: destination) else {
            return .failure(.destinationNotWritable(destination))
        }

        var movedCount = 0

        for source in sources {
            // Check source exists
            guard fileManager.fileExists(atPath: source) else {
                NSLog("CutPaste: File không tồn tại, bỏ qua: \(source)")
                continue
            }

            let fileName = (source as NSString).lastPathComponent
            var destPath = (destination as NSString).appendingPathComponent(fileName)

            // Don't move to same location
            let sourceDir = (source as NSString).deletingLastPathComponent
            let normalizedDest = destination.hasSuffix("/") ? String(destination.dropLast()) : destination
            if sourceDir == normalizedDest {
                NSLog("CutPaste: File đã ở thư mục đích, bỏ qua: \(fileName)")
                continue
            }

            // Handle name conflict
            destPath = resolveConflict(destPath)

            do {
                try fileManager.moveItem(atPath: source, toPath: destPath)
                movedCount += 1
                NSLog("CutPaste: Đã di chuyển \(fileName) → \(destination)")
            } catch {
                return .failure(.moveError(fileName, error.localizedDescription))
            }
        }

        return .success(movedCount)
    }

    private func resolveConflict(_ path: String) -> String {
        guard fileManager.fileExists(atPath: path) else { return path }

        let nsPath = path as NSString
        let directory = nsPath.deletingLastPathComponent
        let ext = nsPath.pathExtension
        let nameWithoutExt = (nsPath.lastPathComponent as NSString).deletingPathExtension

        var counter = 1
        var newPath: String

        repeat {
            let newName: String
            if ext.isEmpty {
                newName = "\(nameWithoutExt) (\(counter))"
            } else {
                newName = "\(nameWithoutExt) (\(counter)).\(ext)"
            }
            newPath = (directory as NSString).appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: newPath)

        return newPath
    }
}
