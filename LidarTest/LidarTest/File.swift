//////
//////  File.swift
//////  LidarTest
//////
//////  Created by Алексей Ведушев on 29.03.2021.
//////
////
//import UIKit
//import Foundation
//import MetalKit
//import RealityKit
//import ARKit
//
//class HZ {
//    let session: ARSession
//    let device: MTLDevice
//
//    var commandQueue: MTLCommandQueue!
//    var capturedTextureChannelY: CVMetalTexture?      /*  Luma               */
//    var capturedTextureChannelCbCr: CVMetalTexture?   /*  Chroma difference  */
//
//    // Captured image texture cache
//    var capturedImageTextureCache: CVMetalTextureCache!
//
//
//
//    init(device: MTLDevice, session: ARSession) {
//        // Create captured image texture cache
//        self.device = device
//        self.session = session
//        loadMetal(device)
//    }
//
//    fileprivate func loadMetal(_ device: MTLDevice) {
//        var textureCache: CVMetalTextureCache?
//        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
//        capturedImageTextureCache = textureCache
//
//        // Create the command queue
//        commandQueue = device.makeCommandQueue()
//    }
//
//    func updateTextures(frame: ARFrame) {
//        let pixelBuffer = frame.capturedImage
//        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else { return }
//
//        capturedTextureChannelY = createTexture(fromPixelBuffer: pixelBuffer,
//                                              pixelFormat: .r8Unorm,
//                                              planeIndex: 0)
//        capturedTextureChannelCbCr = createTexture(fromPixelBuffer: pixelBuffer,
//                                                 pixelFormat: .rg8Unorm,
//                                                 planeIndex: 1)
//    }
//
//    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
//        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
//        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
//
//        var texture: CVMetalTexture? = nil
//        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
//
//        if status != kCVReturnSuccess {
//            texture = nil
//        }
//
//        return texture
//    }
//
//    func draw() {
//        guard let currentFrame = session.currentFrame,
//              let commandBuffer = commandQueue.makeCommandBuffer(),
//              let renderDescriptor = renderDestination.currentRenderPassDescriptor,
//              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)
//        else { return }
//
//        self.updateTextures(frame: currentFrame)
//
//        if rgbUniforms.radius > 0 {
//            var retainingTextures = [capturedTextureChannelY,
//                                     capturedTextureChannelCbCr]
//
//            commandBuffer.addCompletedHandler { buffer in
//                retainingTextures.removeAll()
//            }
//
//            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedTextureChannelY!),
//                                             index: Int(kTextureY.rawValue))
//            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedTextureChannelCbCr!),
//                                             index: Int(kTextureCbCr.rawValue))
//            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
//        }
//    }
//}
