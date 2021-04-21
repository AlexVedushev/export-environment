//
//  ObjExperter.swift
//  LidarTest
//
//  Created by Алексей Ведушев on 09.04.2021.
//

import Foundation
import ARKit
import RealityKit
import MetalKit
import Combine

class SimpleObjExporter {
    
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
        
        DispatchQueue.global().async {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let objURL = directory.appendingPathComponent("\(fileName).obj")
            let mtlURL = directory.appendingPathComponent("\(fileName).mtl")
            
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("metal device could not be created");
                return;
            };
            do {
                try meshAnchors.save(to: objURL, device: device)
                completion([objURL, mtlURL])
            } catch {
                completion([])
                print("failed to write to file");
            }
        }
    }
}

extension simd_float4x4 {
    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension Array where Element == ARMeshAnchor {
    func save(to fileURL: URL, device: MTLDevice) throws {
        let asset = MDLAsset()
        self.forEach {
            let mesh = $0.geometry.toMDLMesh(device: device, transform: $0.transform)
            asset.add(mesh)
        }
        try asset.export(to: fileURL)
    }
}

extension ARMeshGeometry {
    func toMDLMesh(device: MTLDevice, transform: simd_float4x4) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        
        let data = Data.init(bytes: transformedVertexBuffer(transform), count: vertices.stride * vertices.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        
        let indexData = Data.init(bytes: faces.buffer.contents(),
                                  count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        let material = MDLMaterial(name: "material",
                                   scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())

        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: material)
        
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride)
        
        return MDLMesh(vertexBuffer: vertexBuffer,
                       vertexCount: vertices.count,
                       descriptor: vertexDescriptor,
                       submeshes: [submesh])
    }
    
    func transformedVertexBuffer(_ transform: simd_float4x4) -> [Float] {
        var result = [Float]()
        
        for index in 0..<vertices.count {
            let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * index)
            let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
            var vertextTransform = matrix_identity_float4x4
            vertextTransform.columns.3 = SIMD4<Float>(vertex.0, vertex.1, vertex.2, 1)
            let position = (transform * vertextTransform).position
            result.append(position.x)
            result.append(position.y)
            result.append(position.z)
        }
        return result
    }
}
