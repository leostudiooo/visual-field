//
//  MagneticFieldData.swift
//  Visual Field
//
//  Created by Leo Li on 2025/6/19.
//

import Foundation
import simd

/// 磁场数据点结构
struct MagneticFieldDataPoint {
    let position: SIMD3<Float>        // 3D空间位置 (x, y, z)
    let magneticField: SIMD3<Float>   // 磁场向量 (x, y, z) 单位: µT
    let timestamp: Date               // 时间戳
    let fieldStrength: Float          // 磁场强度（向量模长）
    
    init(position: SIMD3<Float>, magneticField: SIMD3<Float>) {
        self.position = position
        self.magneticField = magneticField
        self.timestamp = Date()
        self.fieldStrength = length(magneticField)
    }
}

/// 磁场数据集合
class MagneticFieldDataCollection: ObservableObject {
    @Published var dataPoints: [MagneticFieldDataPoint] = []
    @Published var isRecording: Bool = false
    
    /// 添加数据点
    func addDataPoint(_ point: MagneticFieldDataPoint) {
        dataPoints.append(point)
    }
    
    /// 清除所有数据
    func clearData() {
        dataPoints.removeAll()
    }
    
    /// 获取磁场强度范围
    var fieldStrengthRange: (min: Float, max: Float) {
        guard !dataPoints.isEmpty else { return (0, 0) }
        let strengths = dataPoints.map { $0.fieldStrength }
        return (strengths.min()!, strengths.max()!)
    }
    
    /// 获取空间范围
    var spatialBounds: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !dataPoints.isEmpty else { 
            return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0)) 
        }
        
        let positions = dataPoints.map { $0.position }
        let minX = positions.map { $0.x }.min()!
        let minY = positions.map { $0.y }.min()!
        let minZ = positions.map { $0.z }.min()!
        let maxX = positions.map { $0.x }.max()!
        let maxY = positions.map { $0.y }.max()!
        let maxZ = positions.map { $0.z }.max()!
        
        return (SIMD3<Float>(minX, minY, minZ), SIMD3<Float>(maxX, maxY, maxZ))
    }
}
