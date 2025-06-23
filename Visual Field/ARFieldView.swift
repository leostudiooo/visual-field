import SwiftUI
import ARKit
import RealityKit

struct ARFieldView: UIViewRepresentable {
    let fieldData: [FieldDataPoint]
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 配置 AR 会话
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        
        // 添加磁场可视化
        addFieldVisualization(to: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 更新可视化
        updateFieldVisualization(arView: uiView)
    }
    
    private func addFieldVisualization(to arView: ARView) {
        // 创建锚点
        let anchor = AnchorEntity(world: [0, 0, -1])
        
        // 为每个数据点创建箭头
        for (index, dataPoint) in fieldData.enumerated() {
            let arrow = createMagneticFieldArrow(for: dataPoint, index: index)
            anchor.addChild(arrow)
        }
        
        arView.scene.addAnchor(anchor)
    }
    
    private func updateFieldVisualization(arView: ARView) {
        // 清除现有的可视化
        arView.scene.anchors.removeAll()
        
        // 重新添加可视化
        addFieldVisualization(to: arView)
    }
    
    private func createMagneticFieldArrow(for dataPoint: FieldDataPoint, index: Int) -> ModelEntity {
        // 创建箭头几何体
        let arrowMesh = createArrowMesh(field: dataPoint.magneticField)
        
        // 根据磁场强度选择颜色
        let material = createFieldMaterial(for: dataPoint.magneticField)
        
        let arrowEntity = ModelEntity(mesh: arrowMesh, materials: [material])
        
        // 设置位置
        let position = SIMD3<Float>(
            Float(dataPoint.position.x),
            Float(dataPoint.position.y),
            Float(dataPoint.position.z)
        )
        arrowEntity.position = position
        
        // 设置旋转以指向磁场方向
        let fieldDirection = dataPoint.magneticField.normalized
        let rotation = calculateRotation(for: fieldDirection)
        arrowEntity.orientation = rotation
        
        return arrowEntity
    }
    
    private func createArrowMesh(field: FieldDataPoint.MagneticField) -> MeshResource {
        // 根据磁场强度调整箭头大小
        let magnitude = field.magnitude
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)  // 归一化到 0-1
        let scale = Float(0.05 + normalizedMagnitude * 0.15)  // 箭头长度 0.05-0.2
        
        // 创建圆柱体作为箭头主体
        let cylinderMesh = MeshResource.generateCylinder(height: scale, radius: scale * 0.1)
        
        return cylinderMesh
    }
    
    private func createFieldMaterial(for field: FieldDataPoint.MagneticField) -> RealityFoundation.Material {
        let magnitude = field.magnitude
        
        // 根据磁场强度创建颜色渐变
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)
        
        let color: UIColor
        if normalizedMagnitude < 0.3 {
            // 弱磁场 - 蓝色
            color = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.8)
        } else if normalizedMagnitude < 0.7 {
            // 中等磁场 - 绿色
            color = UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.8)
        } else {
            // 强磁场 - 红色
            color = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.8)
        }
        
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        
        return material
    }
    
    private func calculateRotation(for fieldDirection: FieldDataPoint.MagneticField) -> simd_quatf {
        // 默认箭头指向 Y 轴正方向
        let defaultDirection = SIMD3<Float>(0, 1, 0)
        
        // 目标方向
        let targetDirection = SIMD3<Float>(
            Float(fieldDirection.x),
            Float(fieldDirection.y),
            Float(fieldDirection.z)
        )
        
        // 计算旋转四元数
        let rotationAxis = cross(defaultDirection, targetDirection)
        let rotationAngle = acos(dot(defaultDirection, targetDirection))
        
        if length(rotationAxis) < 0.001 {
            // 方向相同或相反
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        }
        
        let normalizedAxis = normalize(rotationAxis)
        return simd_quatf(angle: rotationAngle, axis: normalizedAxis)
    }
}

// MARK: - AR 视图控制器包装
struct ARFieldViewController: UIViewControllerRepresentable {
    let fieldData: [FieldDataPoint]
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        
        let arView = ARView(frame: .zero)
        controller.view = arView
        
        // 配置 AR 会话
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        
        // 添加关闭按钮
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("关闭", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(context.coordinator, action: #selector(Coordinator.closeAR), for: .touchUpInside)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 添加磁场可视化
        addFieldVisualization(to: arView)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 更新逻辑
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARFieldViewController
        
        init(_ parent: ARFieldViewController) {
            self.parent = parent
        }
        
        @objc func closeAR() {
            parent.isPresented = false
        }
    }
    
    private func addFieldVisualization(to arView: ARView) {
        // 创建锚点
        let anchor = AnchorEntity(world: [0, 0, -1])
        
        // 为每个数据点创建箭头
        for (index, dataPoint) in fieldData.enumerated() {
            let arrow = createMagneticFieldArrow(for: dataPoint, index: index)
            anchor.addChild(arrow)
        }
        
        arView.scene.addAnchor(anchor)
    }
    
    private func createMagneticFieldArrow(for dataPoint: FieldDataPoint, index: Int) -> ModelEntity {
        // 创建箭头几何体
        let arrowMesh = createArrowMesh(field: dataPoint.magneticField)
        
        // 根据磁场强度选择颜色
        let material = createFieldMaterial(for: dataPoint.magneticField)
        
        let arrowEntity = ModelEntity(mesh: arrowMesh, materials: [material])
        
        // 设置位置（添加一些偏移以避免重叠）
        let basePosition = SIMD3<Float>(
            Float(dataPoint.position.x * 0.3),  // 缩放位置
            Float(dataPoint.position.y * 0.3),
            Float(dataPoint.position.z * 0.3)
        )
        
        // 添加网格偏移
        let gridOffset = SIMD3<Float>(
            Float((index % 5) - 2) * 0.2,
            0,
            Float((index / 5) % 5 - 2) * 0.2
        )
        
        arrowEntity.position = basePosition + gridOffset
        
        // 设置旋转以指向磁场方向
        let fieldDirection = dataPoint.magneticField.normalized
        let rotation = calculateRotation(for: fieldDirection)
        arrowEntity.orientation = rotation
        
        return arrowEntity
    }
    
    private func createArrowMesh(field: FieldDataPoint.MagneticField) -> MeshResource {
        // 根据磁场强度调整箭头大小
        let magnitude = field.magnitude
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)
        let scale = Float(0.05 + normalizedMagnitude * 0.15)
        
        // 创建圆柱体作为箭头主体
        let cylinderMesh = MeshResource.generateCylinder(height: scale, radius: scale * 0.1)
        
        return cylinderMesh
    }
    
    private func createFieldMaterial(for field: FieldDataPoint.MagneticField) -> RealityFoundation.Material {
        let magnitude = field.magnitude
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)
        
        let color: UIColor
        if normalizedMagnitude < 0.3 {
            color = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.8)
        } else if normalizedMagnitude < 0.7 {
            color = UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.8)
        } else {
            color = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.8)
        }
        
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        
        return material
    }
    
    private func calculateRotation(for fieldDirection: FieldDataPoint.MagneticField) -> simd_quatf {
        let defaultDirection = SIMD3<Float>(0, 1, 0)
        
        let targetDirection = normalize(SIMD3<Float>(
            Float(fieldDirection.x),
            Float(fieldDirection.y),
            Float(fieldDirection.z)
        ))
        
        let rotationAxis = cross(defaultDirection, targetDirection)
        let dot_product = dot(defaultDirection, targetDirection)
        let rotationAngle = acos(max(-1.0, min(1.0, dot_product)))
        
        if length(rotationAxis) < 0.001 {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        }
        
        let normalizedAxis = normalize(rotationAxis)
        return simd_quatf(angle: rotationAngle, axis: normalizedAxis)
    }
}

// MARK: - 实时 AR 磁场视图
struct ARFieldRealTimeView: UIViewRepresentable {
    @ObservedObject var fieldDataManager: FieldDataManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 配置 AR 会话
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        
        // 存储 ARView 引用到 coordinator
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 当数据管理器状态改变时更新可视化
        context.coordinator.updateVisualization()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: ObservableObject {
        var parent: ARFieldRealTimeView
        var arView: ARView?
        private var currentAnchor: AnchorEntity?
        
        init(_ parent: ARFieldRealTimeView) {
            self.parent = parent
        }
        
        func updateVisualization() {
            guard let arView = arView else { return }
            
            // 如果正在采集或有数据，显示可视化
            if parent.fieldDataManager.isCollecting || !parent.fieldDataManager.collectedData.isEmpty {
                updateFieldVisualization(arView: arView)
            } else {
                // 清除所有可视化
                clearVisualization(arView: arView)
            }
        }
        
        private func updateFieldVisualization(arView: ARView) {
            // 清除现有可视化
            clearVisualization(arView: arView)
            
            let fieldData = parent.fieldDataManager.collectedData
            guard !fieldData.isEmpty else { return }
            
            // 创建新锚点
            let anchor = AnchorEntity(world: [0, 0, -0.5]) // 更近一些，更容易看到
            currentAnchor = anchor
            
            // 为每个数据点创建箭头
            for (index, dataPoint) in fieldData.enumerated() {
                let arrow = createMagneticFieldArrow(for: dataPoint, index: index)
                anchor.addChild(arrow)
            }
            
            arView.scene.addAnchor(anchor)
        }
        
        private func clearVisualization(arView: ARView) {
            if let anchor = currentAnchor {
                arView.scene.removeAnchor(anchor)
                currentAnchor = nil
            }
        }
        
        private func createMagneticFieldArrow(for dataPoint: FieldDataPoint, index: Int) -> ModelEntity {
            // 创建箭头几何体
            let arrowMesh = createArrowMesh(field: dataPoint.magneticField)
            
            // 根据磁场强度选择颜色
            let material = createFieldMaterial(for: dataPoint.magneticField)
            
            let arrowEntity = ModelEntity(mesh: arrowMesh, materials: [material])
            
            // 设置位置（网格布局）
            let gridSize = 5
            let spacing: Float = 0.15
            let row = index / gridSize
            let col = index % gridSize
            
            let position = SIMD3<Float>(
                Float(col - gridSize/2) * spacing,
                Float(row - gridSize/2) * spacing * 0.5,
                0
            )
            arrowEntity.position = position
            
            // 设置旋转以指向磁场方向
            let fieldDirection = dataPoint.magneticField.normalized
            let rotation = calculateRotation(for: fieldDirection)
            arrowEntity.orientation = rotation
            
            return arrowEntity
        }
        
        private func createArrowMesh(field: FieldDataPoint.MagneticField) -> MeshResource {
            // 根据磁场强度调整箭头大小
            let magnitude = field.magnitude
            let normalizedMagnitude = min(magnitude / 60.0, 1.0)  // 地球磁场通常在 25-65 μT
            let scale = Float(0.08 + normalizedMagnitude * 0.12)  // 箭头长度 0.08-0.2
            
            // 创建圆柱体作为箭头主体
            let cylinderMesh = MeshResource.generateCylinder(height: scale, radius: scale * 0.2)
            
            return cylinderMesh
        }
        
        private func createFieldMaterial(for field: FieldDataPoint.MagneticField) -> RealityFoundation.Material {
            let magnitude = field.magnitude
            let normalizedMagnitude = min(magnitude / 60.0, 1.0)
            
            let color: UIColor
            if normalizedMagnitude < 0.4 {
                // 弱磁场 - 蓝色
                color = UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.9)
            } else if normalizedMagnitude < 0.8 {
                // 中等磁场 - 绿色
                color = UIColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.9)
            } else {
                // 强磁场 - 红色
                color = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.9)
            }
            
            var material = UnlitMaterial()
            material.color = .init(tint: color)
            
            return material
        }
        
        private func calculateRotation(for fieldDirection: FieldDataPoint.MagneticField) -> simd_quatf {
            let defaultDirection = SIMD3<Float>(0, 1, 0)
            
            let targetDirection = normalize(SIMD3<Float>(
                Float(fieldDirection.x),
                Float(fieldDirection.y),
                Float(fieldDirection.z)
            ))
            
            let rotationAxis = cross(defaultDirection, targetDirection)
            let dot_product = dot(defaultDirection, targetDirection)
            let rotationAngle = acos(max(-1.0, min(1.0, dot_product)))
            
            if length(rotationAxis) < 0.001 {
                return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
            }
            
            let normalizedAxis = normalize(rotationAxis)
            return simd_quatf(angle: rotationAngle, axis: normalizedAxis)
        }
    }
}
