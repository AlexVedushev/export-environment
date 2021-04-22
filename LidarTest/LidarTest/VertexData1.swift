//
//  Vertex.swift
//  LidarTest
//
//  Created by Алексей Ведушев on 02.04.2021.
//

import Foundation
import simd


struct VertexData1 {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
//    let uv0: vector_float2
}

struct VertexData2 {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let uv0: SIMD2<Float>
}
