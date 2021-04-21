//
//  ViewController.swift
//  LidarTest
//
//  Created by Алексей Ведушев on 29.03.2021.
//

import UIKit
import ARKit
import RealityKit
import ModelIO
import MetalKit
import Combine

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    var simpleObjExporter = SimpleObjExporter()
    let objTextureExporter = ObjTextureExporter()
    var bag = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification

        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        arView.session.delegate = self
    }
    
    @IBAction func buttonTouched(_ sender: Any) {
        objTextureExporter.export(arView)
            .receive(on: DispatchQueue.main)
            .sink { (completion) in
            print(completion)
        } receiveValue: {[unowned self] (urls) in
            let activityViewController = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            present(activityViewController, animated: true, completion: nil)
        }.store(in: &bag)
    }
    
    @IBAction func shareFile(_ button: UIButton) {
        simpleObjExporter.export(arView)
            .receive(on: DispatchQueue.main)
            .sink { (completion) in
            print(completion)
        } receiveValue: {[unowned self] (urls) in
            let activityViewController = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            present(activityViewController, animated: true, completion: nil)
        }.store(in: &bag)
    }

    
    func makeTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int, device: MTLDevice, textureCache: CVMetalTextureCache) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }
    
    fileprivate func saveImage(buffer: CVPixelBuffer, name: String) throws -> URL? {
        let ciImage = CIImage(cvImageBuffer: buffer)
        let uiimage = UIImage(ciImage: ciImage)
        
        guard
            let jpgRepr = uiimage.jpegData(compressionQuality: 0.5),
            let filePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("\(name).jpg") else {
            return nil
        }
        
        if FileManager.default.fileExists(atPath: filePath.path) {
            try FileManager.default.removeItem(at: filePath)
        }
        try jpgRepr.write(to: filePath)
        return filePath
    }
    
    func makeTextureCache(device: MTLDevice) -> CVMetalTextureCache {
        // Create captured image texture cache
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        
        return cache
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let anchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor}) else { return }
//        anchors.forEach { (anchor) in
//            let vertices = anchor.geometry.vertices
//            let modelMatrix = anchor.transform
//
//            for i in 0..<vertices.count {
//                let vertex = anchor.geometry.vertex(at: UInt32(i))
//                textureCoordinate(vertex, modelMatrix: modelMatrix, camera: arView.session.currentFrame?.camera)
//            }
//        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
    }
}



