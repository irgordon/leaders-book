import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

enum RecordFileImport {
    @concurrent static func photo(_ data: Data) async throws -> ImportedRecordFile {
        try Task.checkCancellation()
        guard data.count <= 10 * 1024 * 1024, let image = UIImage(data: data),
              let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 1200, height: 1200)),
              let jpeg = thumbnail.jpegData(compressionQuality: 0.85) else { throw RecordError.invalidAttachment }
        try Task.checkCancellation()
        return try ImportedRecordFile(attachment: try RecordAttachment(name: "Soldier Photo.jpg", kind: .jpeg), data: jpeg)
    }

    @concurrent static func read(_ url: URL, certificate: Bool) async throws -> ImportedRecordFile {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        try Task.checkCancellation()
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw ImportError.missingMetadata }
        guard size > 0, size <= 10 * 1024 * 1024 else { throw RecordError.invalidAttachment }
        let data = try Data(contentsOf: url)
        if certificate && url.pathExtension.lowercased() == "pdf" {
            guard data.starts(with: Data("%PDF-".utf8)) else { throw RecordError.invalidAttachment }
            return try ImportedRecordFile(attachment: try RecordAttachment(name: url.lastPathComponent, kind: .pdf), data: data)
        }
        if certificate {
            guard let image = UIImage(data: data) else { throw RecordError.invalidAttachment }
            // Preserve certificate image resolution so small printed text remains readable.
            let png = data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])
            let jpeg = data.starts(with: [255, 216, 255])
            let content = png || jpeg ? data : image.jpegData(compressionQuality: 0.95)
            guard let content, content.count <= 10 * 1024 * 1024 else { throw RecordError.invalidAttachment }
            let kind: RecordAttachment.Kind = png ? .png : .jpeg
            return try ImportedRecordFile(attachment: try RecordAttachment(name: url.deletingPathExtension().lastPathComponent + "." + kind.rawValue, kind: kind), data: content)
        }
        return try await photo(data)
    }
}

enum ImportError: UserPresentableError, Sendable {
    case cameraUnavailable, cameraDenied, missingCapture, encoding, missingMetadata, invalidImage
    var userMessage: String {
        switch self {
        case .cameraUnavailable: "A camera is not available. Use Photo Library or Files."
        case .cameraDenied: "Allow camera access in Settings to take a photo."
        case .missingCapture: "The camera did not return a captured image. Try taking the photo again."
        case .encoding: "The image could not be encoded. Choose another image."
        case .missingMetadata: "The file provider did not supply the required file size. Choose a local file."
        case .invalidImage: "The saved photo could not be decoded. Replace or remove it in Edit Soldier."
        }
    }
}

private enum PortraitPhase {
    case placeholder
    case loading
    case image(UIImage)
    case failed(AppFailure)
}

struct SoldierPortrait: View {
    let attachment: RecordAttachment?
    let store: LeaderStore
    var pending: Data?
    var size: CGFloat = 72
    @ScaledMetric private var portraitScale: CGFloat = 1
    @State private var phase: PortraitPhase = .placeholder
    var body: some View {
        Group {
            switch phase {
            case .image(let image): Image(uiImage: image).resizable().scaledToFill()
            case .placeholder: Image(systemName: "person.crop.square.fill").resizable().scaledToFit().foregroundStyle(Color.lbTextSecondary).padding(8)
            case .loading: ProgressView()
            case .failed(let failure):
                Button { store.operationFailure = failure } label: {
                    VStack { Image(systemName: "exclamationmark.triangle"); Text("Photo Unavailable").font(.caption2) }
                }.accessibilityLabel(failure.localizedDescription).buttonStyle(LBActionButtonStyle())
            }
        }
        .frame(width: size * portraitScale, height: size * portraitScale).background(Color.lbSurfaceRaised).clipShape(.rect(cornerRadius: 14))
        .task(id: attachment?.id) {
            guard !Task.isCancelled else { return }
            guard let attachment else { phase = .placeholder; return }
            phase = .loading
            do {
                let bytes: Data
                if let pending { bytes = pending } else { bytes = try await store.readAttachment(attachment).data }
                try Task.checkCancellation()
                guard let image = UIImage(data: bytes) else { throw ImportError.invalidImage }
                phase = .image(image)
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                phase = .failed(AppFailure("Open Soldier Photo", underlying: error))
            }
        }
    }
}

private enum PhotoPresentation { case files, camera }

struct SoldierPhotoPicker: View {
    @Binding var attachment: RecordAttachment?
    @Binding var files: [ImportedRecordFile]
    let store: LeaderStore
    let operation: OwnedOperation
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var presentation: PhotoPresentation?
    var body: some View {
        Section("Soldier Photo") {
            SoldierPortrait(attachment: attachment, store: store, pending: files.first { $0.attachment.id == attachment?.id }?.data, size: 96)
            PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Choose From Photo Library", systemImage: "photo.on.rectangle") }
                .disabled(operation.phase.isRunning)
            Button("Choose From Files", systemImage: "folder") { presentation = .files }.disabled(operation.phase.isRunning).buttonStyle(LBActionButtonStyle())
            Button("Take Photo", systemImage: "camera") {
                operation.start("Open Camera") {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else { throw ImportError.cameraUnavailable }
                    guard await AVCaptureDevice.requestAccess(for: .video) else { throw ImportError.cameraDenied }
                    try Task.checkCancellation()
                    presentation = .camera
                }
            }.disabled(operation.phase.isRunning).buttonStyle(LBActionButtonStyle())
            if attachment != nil {
                Button("Remove Photo", systemImage: "trash", role: .destructive) { operation.cancel(); files.removeAll { $0.attachment.id == attachment?.id }; attachment = nil }.foregroundStyle(Color.lbDanger)
            }
            if operation.phase.isRunning { ProgressView("Preparing Photo…") }
        }.leadersBookRow()
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            operation.start("Import Photo") {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ImportError.missingCapture }
                let file = try await RecordFileImport.photo(data)
                try Task.checkCancellation()
                accept(file)
                selectedPhoto = nil
            }
        }
        .fileImporter(isPresented: Binding(get: { presentation == .files }, set: { if !$0 { presentation = nil } }), allowedContentTypes: [.image]) { result in
            operation.start("Import Photo File") {
                let file = try await RecordFileImport.read(result.get(), certificate: false)
                try Task.checkCancellation()
                accept(file)
            }
        }
        .sheet(isPresented: Binding(get: { presentation == .camera }, set: { if !$0 { presentation = nil } })) {
            CameraCapture { result in
                presentation = nil
                operation.start("Capture Photo") {
                    switch try result.get() {
                    case .cancelled: throw CancellationError()
                    case .captured(let data):
                        let file = try await RecordFileImport.photo(data)
                        try Task.checkCancellation()
                        accept(file)
                    }
                }
            }.ignoresSafeArea()
        }
        .alert(item: Binding(get: { operation.phase.failure }, set: { if $0 == nil { operation.dismissFailure() } })) { failure in
            Alert(title: Text("Photo Couldn’t Be Added"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
        }
    }
    private func accept(_ file: ImportedRecordFile) {
        files.removeAll { $0.attachment.id == attachment?.id }
        files.append(file); attachment = file.attachment
    }
}

private enum CameraOutcome { case cancelled, captured(Data) }
private struct CameraCapture: UIViewControllerRepresentable {
    let completion: (Result<CameraOutcome, ImportError>) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController(); controller.sourceType = .camera; controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Result<CameraOutcome, ImportError>) -> Void
        init(completion: @escaping (Result<CameraOutcome, ImportError>) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(.success(.cancelled)) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else { completion(.failure(.missingCapture)); return }
            guard let data = image.jpegData(compressionQuality: 0.9) else { completion(.failure(.encoding)); return }
            completion(.success(.captured(data)))
        }
    }
}
