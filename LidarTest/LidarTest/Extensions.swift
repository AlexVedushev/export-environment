//
//  Extensions.swift
//  LidarTest
//
//  Created by Алексей Ведушев on 09.04.2021.
//

import Foundation
import MetalKit
import RealityKit
import ARKit

extension MDLMaterial {
    func setTextureProperties(_ textures: [MDLMaterialSemantic : String]) -> Void {
        for (key,value) in textures {
            guard let url = Bundle.main.url(forResource: value, withExtension: "") else {
                fatalError("Failed to find URL for resource \(value).")
            }
            let property = MDLMaterialProperty(name:value, semantic: key, url: url)
            self.setProperty(property)
        }
    }
}

func data<T>(for array: [T]) -> Data {
    return array.withUnsafeBufferPointer { buffer in
        return Data(buffer: buffer)
    }
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    
    func normal(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
}
