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

class ObjTextureExporter {
    
    func export(_ arView: ARView) -> AnyPublisher<[URL], Error> {
        let fileName = "MyFirstMesh"
        
        return Future<[URL], Error> {[unowned self] (promise) in
            exportMesh(fileName, arView: arView) {(urls) in
                promise(.success(urls))
            }
        }.eraseToAnyPublisher()
    }
    
    private func exportMesh(_ fileName: String, arView: ARView, completion: @escaping ([URL]) -> Void) {
        guard let meshAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) else {
            completion([])
            return
        }
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
        
        DispatchQueue.global().async {
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("metal device could not be created");
                return;
            };
            do {
                try meshAnchors.save1(to: objURL, device: device)
                let zipFilePath = try Zip.quickZipFiles([directoryPath], fileName: folderName)
                completion([zipFilePath])
            } catch {
                completion([])
                print(error);
            }
        }
    }
}

extension Array where Element == ARMeshAnchor {
    func save1(to fileURL: URL, device: MTLDevice) throws {
        let asset = MDLAsset()
        self.forEach {
            let mesh = $0.geometry.toMDLMesh1(device: device, transform: $0.transform)
            asset.add(mesh)
        }
        try asset.export(to: fileURL)
    }
}

extension ARMeshGeometry {
    func toMDLMesh1(device: MTLDevice, transform: simd_float4x4) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDataArray = transformedVertexBufferToVertexData(transform)
        let data = Data.init(bytes: vertexDataArray, count: MemoryLayout<Vertex>.size * vertexDataArray.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        
        let indexData = Data.init(bytes: faces.buffer.contents(),
                                  count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        let material = MDLMaterial(name: "material",
                                   scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        let property = MDLMaterialProperty(name:"baseColor", semantic: .baseColor, string: "_texture.jpg")
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
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Vertex>.size)
        
        return MDLMesh(vertexBuffer: vertexBuffer,
                       vertexCount: vertices.count,
                       descriptor: vertexDescriptor,
                       submeshes: [submesh])
    }
    
    func transformedVertexBufferToVertexData(_ transform: simd_float4x4) -> [Vertex] {
        var result = [Vertex]()
        
        for index in 0..<vertices.count {
            let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * index)
            let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
            var vertextTransform = matrix_identity_float4x4
            vertextTransform.columns.3 = SIMD4<Float>(vertex.0, vertex.1, vertex.2, 1)
            let position = (transform * vertextTransform).position
            
            let normalPointer = normals.buffer.contents().advanced(by: normals.offset + normals.stride * index)
            let normal = normalPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
            
            result.append(Vertex(position: position,
                                 normal: SIMD3(normal.0, normal.1, normal.2)))
        }
        return result
    }
}
