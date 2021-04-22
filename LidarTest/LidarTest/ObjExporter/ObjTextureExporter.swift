//
//  ObjTextureExporter.swift
//  LidarTest
//
//  Created by Алексей Ведушев on 09.04.2021.
//

import Foundation
import ARKit
import RealityKit
import Combine
import MetalKit
import Zip

typealias Vertex = VertexData2

class ObjTextureExporter {
    
    var pixelBufferDict: [String : CVPixelBuffer] = [:]
    var anchorImageNameDict: [String : String] = [:]
    
    func export(_ arView: ARView) -> AnyPublisher<[URL], Error> {
        let fileName = "MyFirstMesh"
        
        return Future<[URL], Error> {[unowned self] (promise) in
            exportMesh(fileName, arView: arView) {(urls) in
                promise(.success(urls))
            }
        }.eraseToAnyPublisher()
    }
    
    private func exportMesh(_ fileName: String, arView: ARView, completion: @escaping ([URL]) -> Void) {
        guard let currentFrame = arView.session.currentFrame else {
            completion([])
            return
        }
        let meshAnchors = currentFrame.anchors.compactMap({ $0 as? ARMeshAnchor })
        let camera = currentFrame.camera
        let fileManager = FileManager.default
        let folderName = UUID().uuidString
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directoryPath = documentDirectory.appendingPathComponent(folderName)
        let objURL = directoryPath.appendingPathComponent("\(fileName).obj")

        if !fileManager.fileExists(atPath: directoryPath.relativePath) {
            do {
                try fileManager.createDirectory(atPath: directoryPath.relativePath,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        anchorImageNameDict.values.forEach { (imageName) in
            guard let pixelBuffer = pixelBufferDict[imageName] else { return }
            let ciImag = CIImage(cvPixelBuffer: pixelBuffer)
            let image = UIImage.init(ciImage: ciImag)
            let data = image.jpegData(compressionQuality: 0.8)
            let path = directoryPath.appendingPathComponent(imageName + ".jpeg")
            try? data?.write(to: path)
        }
        
        DispatchQueue.global().async { [weak self] in
            guard
                let self = self,
                let device = MTLCreateSystemDefaultDevice()
            else {
                print("metal device could not be created");
                return;
            };
            do {
                try self.save1(to: objURL, anchors: meshAnchors, device: device, camera: camera)
                let zipFilePath = try Zip.quickZipFiles([directoryPath], fileName: folderName)
                completion([zipFilePath])
            } catch {
                completion([])
                print(error);
            }
        }
    }
    
    private func save1(to fileURL: URL, anchors: [ARMeshAnchor], device: MTLDevice, camera: ARCamera) throws {
        let asset = MDLAsset()
        anchors.forEach {
            let imageName = anchorImageNameDict[$0.identifier.uuidString] ?? ""
            let mesh = toMDLMesh1(geometry: $0.geometry,
                                  imageName: imageName,
                                  device: device,
                                  camera: camera,
                                  transform: $0.transform)
            asset.add(mesh)
        }
        try asset.export(to: fileURL)
    }
    
    private func toMDLMesh1(geometry: ARMeshGeometry,
                            imageName: String,
                            device: MTLDevice,
                            camera: ARCamera,
                            transform: simd_float4x4) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDataArray = geometry.transformedVertexBufferToVertexData(transform, camera: camera)
        let data = Data.init(bytes: vertexDataArray, count: MemoryLayout<VertexData1>.size * vertexDataArray.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        
        let indexData = Data.init(bytes: geometry.faces.buffer.contents(),
                                  count: geometry.faces.bytesPerIndex * geometry.faces.count * geometry.faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        let material = MDLMaterial(name: "material",
                                   scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        
        let property = MDLMaterialProperty(name:"baseColor", semantic: .baseColor, string: "_\(imageName).jpeg")
        material.setProperty(property)
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: geometry.faces.count * geometry.faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: material)
        
        let vertexDescriptor = MDLVertexDescriptor()
        var offset = 0
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += MemoryLayout<vector_float3>.stride
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += MemoryLayout<vector_float3>.stride
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: offset,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Vertex>.stride)
        
        return MDLMesh(vertexBuffer: vertexBuffer,
                       vertexCount: geometry.vertices.count,
                       descriptor: vertexDescriptor,
                       submeshes: [submesh])
    }
}

extension Array where Element == ARMeshAnchor {
    func save1(to fileURL: URL, device: MTLDevice, camera: ARCamera) throws {
        let asset = MDLAsset()
        self.forEach {
            let mesh = $0.geometry.toMDLMesh1(device: device,
                                              camera: camera,
                                              transform: $0.transform)
            asset.add(mesh)
        }
        try asset.export(to: fileURL)
    }
}

extension ARMeshGeometry {
    func toMDLMesh1(device: MTLDevice, camera: ARCamera, transform: simd_float4x4) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDataArray = transformedVertexBufferToVertexData(transform, camera: camera)
        let data = Data.init(bytes: vertexDataArray, count: MemoryLayout<VertexData1>.size * vertexDataArray.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        
        let indexData = Data.init(bytes: faces.buffer.contents(),
                                  count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        let material = MDLMaterial(name: "material",
                                   scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        let property = MDLMaterialProperty(name:"baseColor", semantic: .baseColor, string: "_texture.jpeg")
        material.setProperty(property)
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: material)
        
        let vertexDescriptor = MDLVertexDescriptor()
        var offset = 0
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += MemoryLayout<vector_float3>.stride
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += MemoryLayout<vector_float3>.stride
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: offset,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Vertex>.stride)
        
        return MDLMesh(vertexBuffer: vertexBuffer,
                       vertexCount: vertices.count,
                       descriptor: vertexDescriptor,
                       submeshes: [submesh])
    }
    
    func transformedVertexBufferToVertexData(_ anchorTransform: simd_float4x4, camera: ARCamera) -> [Vertex] {
        var result = [Vertex]()
        
        for index in 0..<vertices.count {
            let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * index)
            let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
            var vertextTransform = matrix_identity_float4x4
            vertextTransform.columns.3 = SIMD4<Float>(vertex.0, vertex.1, vertex.2, 1)
            let position = (anchorTransform * vertextTransform).position
            
            let normalPointer = normals.buffer.contents().advanced(by: normals.offset + normals.stride * index)
            let normal = normalPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
            
            let textureCoordinate = getTextureCoordinate(SIMD3<Float>(vertex.0, vertex.1, vertex.2),
                                                         modelMatrix: anchorTransform,
                                                         camera: camera)
            
            result.append(
                Vertex(position: position,
                           normal: SIMD3(normal.0, normal.1, normal.2),
                           uv0: textureCoordinate
                )
            )
        }
        return result
    }
}

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

//func getTextureCoordinate(_ vertex: SIMD3<Float>, modelMatrix: simd_float4x4, camera: ARCamera) -> vector_float2 {
//    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
//    let size = camera.imageResolution
//    let world_vertex4 = simd_mul(modelMatrix, vertex4)
//    let world_vector3 = simd_float3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
//    let pt = camera.projectPoint(world_vector3,
//                                 orientation: .portrait,
//                                 viewportSize: CGSize(
//                                    width: CGFloat(size.height),
//                                    height: CGFloat(size.width)))
//    let v = 1.0 - Float(pt.x) / Float(size.height)
//    let u = Float(pt.y) / Float(size.width)
//    return vector_float2(u, v)
//}
