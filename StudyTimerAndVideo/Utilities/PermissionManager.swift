import AVFoundation
import Photos
import UIKit

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
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = granted
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            photoLibraryPermissionGranted = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    self.photoLibraryPermissionGranted = (status == .authorized || status == .limited)
                }
            }
        default:
            photoLibraryPermissionGranted = false
        }
    }
    
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
