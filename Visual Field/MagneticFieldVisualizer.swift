//
//  MagneticFieldVisualizer.swift
//  Visual Field
//
//  Created by Leo Li on 2025/6/19.
//

import Foundation
import RealityKit
import UIKit
import simd

/// 磁场可视化器
class MagneticFieldVisualizer {
    
    /// 可视化类型
    enum VisualizationType {
        case vectors      // 向量箭头
        case heatMap      // 热力图
        case particles    // 粒子系统
    }
    
    /// 创建磁场向量可视化
    static func createVectorVisualization(
        for dataPoints: [MagneticFieldDataPoint],
        type: VisualizationType = .vectors,
        scale: Float = 0.01
    ) -> [Entity] {
        
        switch type {
        case .vectors:
            return createVectorArrows(dataPoints: dataPoints, scale: scale)
        case .heatMap:
            return createHeatMapSpheres(dataPoints: dataPoints, scale: scale)
        case .particles:
            return createParticleEffects(dataPoints: dataPoints, scale: scale)
        }
    }
    
    /// 创建向量箭头
    private static func createVectorArrows(dataPoints: [MagneticFieldDataPoint], scale: Float) -> [Entity] {
        var entities: [Entity] = []
        
        // 计算磁场强度范围用于颜色映射
        let fieldRange = getFieldStrengthRange(dataPoints)
        
        for point in dataPoints {
            let arrow = createArrowEntity(
                position: point.position,
                direction: normalize(point.magneticField),
                magnitude: point.fieldStrength,
                fieldRange: fieldRange,
                scale: scale
            )
            entities.append(arrow)
        }
        
        return entities
    }
    
    /// 创建热力图球体
    private static func createHeatMapSpheres(dataPoints: [MagneticFieldDataPoint], scale: Float) -> [Entity] {
        var entities: [Entity] = []
        
        let fieldRange = getFieldStrengthRange(dataPoints)
        
        for point in dataPoints {
            let sphere = createHeatMapSphere(
                position: point.position,
                fieldStrength: point.fieldStrength,
                fieldRange: fieldRange,
                scale: scale
            )
            entities.append(sphere)
        }
        
        return entities
    }
    
    /// 创建粒子效果
    private static func createParticleEffects(dataPoints: [MagneticFieldDataPoint], scale: Float) -> [Entity] {
        // 简化实现，返回向量箭头
        return createVectorArrows(dataPoints: dataPoints, scale: scale)
    }
    
    /// 创建箭头实体
    private static func createArrowEntity(
        position: SIMD3<Float>,
        direction: SIMD3<Float>,
        magnitude: Float,
        fieldRange: (min: Float, max: Float),
        scale: Float
    ) -> Entity {
        
        let entity = Entity()
        
        // 创建箭头几何体（圆柱体 + 圆锥体）
        let cylinderMesh = MeshResource.generateCylinder(height: 0.02, radius: 0.002)
        let coneMesh = MeshResource.generateCone(height: 0.01, radius: 0.004)
        
        // 根据磁场强度映射颜色
        let normalizedStrength = (magnitude - fieldRange.min) / (fieldRange.max - fieldRange.min)
        let color = interpolateColor(factor: normalizedStrength)
        let material = SimpleMaterial(color: color, isMetallic: false)
        
        // 创建圆柱体（箭身）
        let cylinder = Entity()
        cylinder.components.set(ModelComponent(mesh: cylinderMesh, materials: [material]))
        cylinder.position = SIMD3<Float>(0, 0.01, 0)
        
        // 创建圆锥体（箭头）
        let cone = Entity()
        cone.components.set(ModelComponent(mesh: coneMesh, materials: [material]))
        cone.position = SIMD3<Float>(0, 0.025, 0)
        
        entity.addChild(cylinder)
        entity.addChild(cone)
        
        // 设置位置和方向
        entity.position = position
        
        // 计算旋转使箭头指向磁场方向
        if length(direction) > 0 {
            let rotation = calculateRotation(from: SIMD3<Float>(0, 1, 0), to: direction)
            entity.orientation = rotation
        }
        
        // 根据磁场强度调整大小
        let sizeScale = 0.5 + normalizedStrength * 1.5 // 0.5-2.0倍缩放
        entity.scale = SIMD3<Float>(repeating: sizeScale * scale)
        
        return entity
    }
    
    /// 创建热力图球体
    private static func createHeatMapSphere(
        position: SIMD3<Float>,
        fieldStrength: Float,
        fieldRange: (min: Float, max: Float),
        scale: Float
    ) -> Entity {
        
        let entity = Entity()
        
        let sphereMesh = MeshResource.generateSphere(radius: 0.01)
        
        // 根据磁场强度映射颜色
        let normalizedStrength = (fieldStrength - fieldRange.min) / (fieldRange.max - fieldRange.min)
        let color = interpolateColor(factor: normalizedStrength)
        let material = SimpleMaterial(color: color, isMetallic: false)
        
        entity.components.set(ModelComponent(mesh: sphereMesh, materials: [material]))
        entity.position = position
        
        // 根据磁场强度调整大小
        let sizeScale = 0.5 + normalizedStrength * 1.5
        entity.scale = SIMD3<Float>(repeating: sizeScale * scale)
        
        return entity
    }
    
    /// 获取磁场强度范围
    private static func getFieldStrengthRange(_ dataPoints: [MagneticFieldDataPoint]) -> (min: Float, max: Float) {
        guard !dataPoints.isEmpty else { return (0, 1) }
        let strengths = dataPoints.map { $0.fieldStrength }
        return (strengths.min()!, strengths.max()!)
    }
    
    /// 颜色插值（蓝色 -> 绿色 -> 红色）
    private static func interpolateColor(factor: Float) -> UIColor {
        let clampedFactor = max(0, min(1, factor))
        
        if clampedFactor <= 0.5 {
            // 蓝色到绿色
            let t = clampedFactor * 2
            return UIColor(
                red: 0,
                green: CGFloat(t),
                blue: CGFloat(1 - t),
                alpha: 0.8
            )
        } else {
            // 绿色到红色
            let t = (clampedFactor - 0.5) * 2
            return UIColor(
                red: CGFloat(t),
                green: CGFloat(1 - t),
                blue: 0,
                alpha: 0.8
            )
        }
    }
    
    /// 计算旋转四元数
    private static func calculateRotation(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let fromNorm = normalize(from)
        let toNorm = normalize(to)
        
        let dot = dot(fromNorm, toNorm)
        
        if dot > 0.9999 {
            // 向量几乎相同
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        } else if dot < -0.9999 {
            // 向量几乎相反
            let perpendicular = abs(fromNorm.x) < 0.9 ? 
                SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
            let axis = normalize(cross(fromNorm, perpendicular))
            return simd_quatf(angle: Float.pi, axis: axis)
        }
        
        let axis = cross(fromNorm, toNorm)
        let angle = acos(abs(dot))
        return simd_quatf(angle: angle, axis: normalize(axis))
    }
}
