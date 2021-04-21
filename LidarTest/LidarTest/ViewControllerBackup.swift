//
//  ViewControllerBackup.swift
//  LidarTest
//
//  Created by Алексей Ведушев on 09.04.2021.
//

import UIKit
import ARKit
import RealityKit
import ModelIO
import MetalKit

class ViewControllerBackup: UIViewController {
    
    @IBOutlet var arView: ARView!
    
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
        saveButtonTapped1()
    }
    
    //modelMatrix = meshAnchor.transform
    func getTextureCoordinate(_ vertex: SIMD3<Float>, modelMatrix: simd_float4x4, camera: ARCamera) -> vector_float2 {
        let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
        let size = camera.imageResolution
            let world_vertex4 = simd_mul(modelMatrix, vertex4)
            let world_vector3 = simd_float3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
            let pt = camera.projectPoint(world_vector3,
                orientation: .portrait,
                viewportSize: CGSize(
                    width: CGFloat(size.height),
                    height: CGFloat(size.width)))
            let v = 1.0 - Float(pt.x) / Float(size.height)
            let u = Float(pt.y) / Float(size.width)
            return vector_float2(u, v)
    }
    
    func saveButtonTapped1() {
        print("Saving is executing...")
        
        guard let frame = arView.session.currentFrame
        else { fatalError("Can't get ARFrame") }
        
        guard let device = MTLCreateSystemDefaultDevice()
        else { fatalError("Can't create MTLDevice") }
        
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)
        let meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        let camera = frame.camera
        let imageBuffer = frame.capturedImage
        
        for ma in meshAnchors {
            let geometry = ma.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces
            let vertexPointer = vertices.buffer.contents()
            let facePointer = faces.buffer.contents()
            
            var vertexes = [Vertex]()
            
            for vtxIndex in 0 ..< vertices.count {
//                let vertex = geometry.vertex(at: UInt32(vtxIndex))
                let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * vtxIndex)
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                
                let normal = ma.geometry.normal(at: UInt32(vtxIndex))
                var vertexLocalTransform = matrix_identity_float4x4
                
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.x,
                                                              y: vertex.y,
                                                              z: vertex.z,
                                                              w: 1.0)
                let textureCoordinate = getTextureCoordinate(vertex, modelMatrix: ma.transform, camera: camera)
                
                let vertexData = Vertex(position: [], normal: SIMD3<Float>.zero)
//                                        normal: normal,
//                                        uv0: textureCoordinate)
                vertexes.append(vertexData)
            }
            
            let byteCountVertices = vertices.count * vertices.stride
            let byteCountFaces = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            
//            let vertexBuffer = allocator.newBuffer(MemoryLayout<Vertex>.size * vertexes.count,
//                                                   type: .vertex)
//            let vertexMap = vertexBuffer.map()
//            vertexMap.bytes.assumingMemoryBound(to: Vertex.self)
//                .assign(from: vertexes,
//                        count: vertexes.count)
//            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: vertexPointer,
//                                                              count: byteCountVertices,
//                                                              deallocator: .none), type: .vertex)
            
            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: vertexes),
                                                              count: vertexes.count * MemoryLayout<Vertex>.size,
                                                                          deallocator: .none),
                                                   type: .vertex)
            
            
//            let indexBuffer = allocator.newBuffer(MemoryLayout<UInt16>.stride * indices.count, type: .index)
//            let indexMap = indexBuffer.map()
//            indexMap.bytes.assumingMemoryBound(to: UInt16.self).assign(from: indices, count: indices.count)
            let data = Data(bytesNoCopy: facePointer,
                            count: byteCountFaces,
                            deallocator: .none)
            let indexBuffer = allocator.newBuffer(with: data, type: .index)
            
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let scatteringFunction = MDLPhysicallyPlausibleScatteringFunction()
            let material = MDLMaterial(name: "material",
                                       scatteringFunction: scatteringFunction)
            
            let property = MDLMaterialProperty(name:"baseColor", semantic: .baseColor, string: "_texture.jpg")
            material.setProperty(property)
            
            let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                     indexCount: indexCount,
                                     indexType: .uInt16,
                                     geometryType: .triangles,
                                     material: material)
            
            let vertexFormat = MTKModelIOVertexFormatFromMetal(vertices.format)
            let vertexDescriptor = MDLVertexDescriptor()
            var offset = 0
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                                format: .float3,
                                                                offset: 0,
                                                                bufferIndex: 0)
//            offset += MemoryLayout<vector_float3>.stride
//            vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
//                                                                format: .float3,
//                                                                offset: offset,
//                                                                bufferIndex: 0)
//            offset += MemoryLayout<vector_float3>.stride
//            vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
//                                                                format: .float2,
//                                                                offset: offset,
//                                                                bufferIndex: 0)
            
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Vertex>.size)
            
            let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                               vertexCount: ma.geometry.vertices.count,
                               descriptor: vertexDescriptor,
                               submeshes: [submesh])
            asset.add(mesh)
        }
        
        let filePath = FileManager.default.urls(for: .documentDirectory,
                                                in: .userDomainMask).first!
        let fileName = "model"
        let usd: URL = filePath.appendingPathComponent("\(fileName).obj")
        let mtl: URL = filePath.appendingPathComponent("\(fileName).mtl")
        
        if MDLAsset.canExportFileExtension("obj") {
            do {
                try asset.export(to: usd)
                let textureURL = try saveImage(buffer: imageBuffer, name: "texture")
                let controller = UIActivityViewController(activityItems: [usd, mtl, textureURL!],
                                                          applicationActivities: nil)
                self.present(controller, animated: true, completion: nil)
                
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Can't export USD")
        }
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
    
    @IBAction func shareFile(_ button: UIButton) {
        let fileName = "MyFirstMesh.obj"
        
        exportMesh(fileName) {[weak self] (url) in
            guard let url = url else { return }
            
            DispatchQueue.main.async {[weak self] in
                let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self?.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func exportMesh(_ fileName: String, completion: @escaping (URL?) -> Void) {
        guard let meshAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) else {
            completion(nil)
            return
        }
        
        DispatchQueue.global().async {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = directory.appendingPathComponent("MyFirstMesh.obj")
            
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("metal device could not be created");
                return;
            };
            do {
                try meshAnchors.save(to: url, device: device)
                completion(url)
            } catch {
                completion(nil)
                print("failed to write to file");
            }
        }
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
    
    func makeTextureCache(device: MTLDevice) -> CVMetalTextureCache {
        // Create captured image texture cache
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        
        return cache
    }
}

extension ViewControllerBackup: ARSessionDelegate {
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
