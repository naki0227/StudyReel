import AVFoundation
import Photos
import UIKit

@MainActor
class PermissionManager: ObservableObject {
    @Published var cameraPermissionGranted = false
    @Published var photoLibraryPermissionGranted = false
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
    }

    var hasRequiredPermissions: Bool {
        cameraPermissionGranted && photoLibraryPermissionGranted
    }

    var needsSettingsRedirect: Bool {
        cameraAuthorizationStatus != .notDetermined && photoAuthorizationStatus != .notDetermined && !hasRequiredPermissions
    }

    func requestRequiredPermissionsIfNeeded() async {
        if cameraAuthorizationStatus == .notDetermined {
            await requestCameraAccess()
        }

        if photoAuthorizationStatus == .notDetermined {
            await requestPhotoLibraryAccess()
        }

        checkPermissions()
    }

    private func checkCameraPermission() {
        switch cameraAuthorizationStatus {
        case .authorized:
            cameraPermissionGranted = true
        default:
            cameraPermissionGranted = false
        }
    }

    private func checkPhotoLibraryPermission() {
        switch photoAuthorizationStatus {
        case .authorized, .limited:
            photoLibraryPermissionGranted = true
        default:
            photoLibraryPermissionGranted = false
        }
    }

    private var cameraAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    private var photoAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }

    private func requestCameraAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermissionGranted = granted
    }

    private func requestPhotoLibraryAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        photoLibraryPermissionGranted = (status == .authorized || status == .limited)
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
