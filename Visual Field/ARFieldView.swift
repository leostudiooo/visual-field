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
        // 创建复合箭头实体
        let arrowEntity = ModelEntity()
        
        // 箭头参数
        let magnitude = dataPoint.magneticField.magnitude
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)
        let baseLength = Float(0.01)  // 基础长度 1cm
        let lengthMultiplier = Float(0.5 + normalizedMagnitude * 2.0)  // 长度倍数 0.5-2.5
        let arrowLength = baseLength * lengthMultiplier
        let arrowRadius = arrowLength * 0.05  // 半径为长度的5%
        
        // 创建材质
        let material = createFieldMaterial(for: dataPoint.magneticField)
        
        // 创建箭头主体（圆柱体）
        let cylinderHeight = arrowLength * 0.8  // 主体占80%长度
        let cylinderMesh = MeshResource.generateCylinder(height: cylinderHeight, radius: arrowRadius)
        let cylinderEntity = ModelEntity(mesh: cylinderMesh, materials: [material])
        cylinderEntity.position = SIMD3<Float>(0, cylinderHeight / 2, 0)  // 向上偏移一半高度
        
        // 创建箭头头部（圆锥体）
        let coneHeight = arrowLength * 0.2  // 头部占20%长度
        let coneRadius = arrowRadius * 2.5   // 头部半径更大
        let coneMesh = MeshResource.generateCone(height: coneHeight, radius: coneRadius)
        let coneEntity = ModelEntity(mesh: coneMesh, materials: [material])
        coneEntity.position = SIMD3<Float>(0, cylinderHeight + coneHeight / 2, 0)  // 放在主体顶部
        
        // 将主体和头部添加到复合实体
        arrowEntity.addChild(cylinderEntity)
        arrowEntity.addChild(coneEntity)
        
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
        
        // 大幅缩小箭头基础大小，增加长度变化范围
        let baseLength = Float(0.01)  // 基础长度 1cm
        let lengthMultiplier = Float(0.5 + normalizedMagnitude * 2.0)  // 长度倍数 0.5-2.5
        let arrowLength = baseLength * lengthMultiplier
        let arrowRadius = arrowLength * 0.05  // 半径为长度的5%
        
        // 创建圆柱体作为箭头主体
        let cylinderMesh = MeshResource.generateCylinder(height: arrowLength, radius: arrowRadius)
        
        return cylinderMesh
    }
    
    private func createFieldMaterial(for field: FieldDataPoint.MagneticField) -> RealityFoundation.Material {
        let magnitude = field.magnitude
        
        // 根据磁场强度创建颜色渐变 (蓝-青-绿-黄-红)
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)
        
        let color: UIColor
        if normalizedMagnitude < 0.2 {
            // 很弱磁场 - 深蓝色
            let ratio = normalizedMagnitude / 0.2
            color = UIColor(red: 0.1 * ratio, green: 0.1 * ratio, blue: 0.8 + 0.2 * ratio, alpha: 0.9)
        } else if normalizedMagnitude < 0.4 {
            // 弱磁场 - 蓝色到青色
            let ratio = (normalizedMagnitude - 0.2) / 0.2
            color = UIColor(red: 0.1, green: 0.1 + 0.6 * ratio, blue: 1.0, alpha: 0.9)
        } else if normalizedMagnitude < 0.6 {
            // 中等磁场 - 青色到绿色
            let ratio = (normalizedMagnitude - 0.4) / 0.2
            color = UIColor(red: 0.1, green: 0.7 + 0.3 * ratio, blue: 1.0 - 0.5 * ratio, alpha: 0.9)
        } else if normalizedMagnitude < 0.8 {
            // 较强磁场 - 绿色到黄色
            let ratio = (normalizedMagnitude - 0.6) / 0.2
            color = UIColor(red: 0.1 + 0.9 * ratio, green: 1.0, blue: 0.5 - 0.5 * ratio, alpha: 0.9)
        } else {
            // 强磁场 - 黄色到红色
            let ratio = (normalizedMagnitude - 0.8) / 0.2
            color = UIColor(red: 1.0, green: 1.0 - 0.8 * ratio, blue: 0.0, alpha: 0.9)
        }
        
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        
        return material
    }
    
    private func calculateRotation(for fieldDirection: FieldDataPoint.MagneticField) -> simd_quatf {
        // 默认箭头指向 Y 轴正方向
        let defaultDirection = SIMD3<Float>(0, 1, 0)
        
        // 目标方向（归一化）
        let targetDirection = normalize(SIMD3<Float>(
            Float(fieldDirection.x),
            Float(fieldDirection.y),
            Float(fieldDirection.z)
        ))
        
        // 检查是否为零向量或接近零向量
        if length(targetDirection) < 0.001 {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        }
        
        // 计算旋转轴和角度
        let cosTheta = dot(defaultDirection, targetDirection)
        
        // 处理方向相同的情况
        if cosTheta > 0.9999 {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        }
        
        // 处理方向相反的情况
        if cosTheta < -0.9999 {
            // 选择一个垂直轴进行180度旋转
            let perpAxis = abs(defaultDirection.x) > 0.1 ? 
                SIMD3<Float>(0, 0, 1) : SIMD3<Float>(1, 0, 0)
            return simd_quatf(angle: Float.pi, axis: perpAxis)
        }
        
        // 一般情况：计算旋转轴和角度
        let rotationAxis = normalize(cross(defaultDirection, targetDirection))
        let rotationAngle = acos(max(-1.0, min(1.0, cosTheta)))  // 限制范围避免数值错误
        
        return simd_quatf(angle: rotationAngle, axis: rotationAxis)
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
        // 创建复合箭头实体
        let arrowEntity = ModelEntity()
        
        // 箭头参数 - 更小更精细的尺寸
        let magnitude = dataPoint.magneticField.magnitude
        let normalizedMagnitude = min(magnitude / 100.0, 1.0)
        let baseLength = Float(0.005)  // 进一步缩小基础长度到0.5cm
        let lengthMultiplier = Float(1.0 + normalizedMagnitude * 3.0)  // 长度倍数 1.0-4.0
        let arrowLength = baseLength * lengthMultiplier
        let arrowRadius = arrowLength * 0.03  // 更细的半径
        
        // 创建材质
        let material = createFieldMaterial(for: dataPoint.magneticField)
        
        // 创建箭头主体（圆柱体）
        let cylinderHeight = arrowLength * 0.75  // 主体占75%长度
        let cylinderMesh = MeshResource.generateCylinder(height: cylinderHeight, radius: arrowRadius)
        let cylinderEntity = ModelEntity(mesh: cylinderMesh, materials: [material])
        cylinderEntity.position = SIMD3<Float>(0, cylinderHeight / 2, 0)  // 向上偏移一半高度
        
        // 创建箭头头部（圆锥体）
        let coneHeight = arrowLength * 0.25  // 头部占25%长度
        let coneRadius = arrowRadius * 3.0   // 头部半径更大，更明显
        let coneMesh = MeshResource.generateCone(height: coneHeight, radius: coneRadius)
        let coneEntity = ModelEntity(mesh: coneMesh, materials: [material])
        coneEntity.position = SIMD3<Float>(0, cylinderHeight + coneHeight / 2, 0)  // 放在主体顶部
        
        // 将主体和头部添加到复合实体
        arrowEntity.addChild(cylinderEntity)
        arrowEntity.addChild(coneEntity)
        
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
        
        // 连接 AR 会话到 FieldDataManager
        #if canImport(ARKit) && os(iOS)
        fieldDataManager.arSession = arView.session
        #endif
        
        // 存储 ARView 的引用
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 当采集状态或数据变化时更新可视化
        context.coordinator.updateVisualization()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARFieldRealTimeView
        var arView: ARView?
        private var arrowAnchors: [AnchorEntity] = []  // 存储所有箭头锚点
        
        init(_ parent: ARFieldRealTimeView) {
            self.parent = parent
        }
        
        func updateVisualization() {
            guard let arView = arView else { return }
            
            // 清除现有的所有箭头锚点
            for anchor in arrowAnchors {
                arView.scene.removeAnchor(anchor)
            }
            arrowAnchors.removeAll()
            
            // 如果有数据就显示箭头（不论是否正在采集）
            if !parent.fieldDataManager.collectedData.isEmpty {
                addFieldVisualization(to: arView)
            }
        }
        
        private func addFieldVisualization(to arView: ARView) {
            // 性能优化：限制显示的箭头数量
            let maxArrows = 100
            let dataToShow = parent.fieldDataManager.collectedData.suffix(maxArrows)
            
            // 添加一个固定的测试箭头用于调试（指向正Y方向）
            addTestArrow(to: arView)
            
            // 为每个数据点在其空间位置创建独立的箭头锚点
            for (index, dataPoint) in dataToShow.enumerated() {
                // 将 FieldDataPoint.Position 转换为 SIMD3<Float>
                let position = SIMD3<Float>(
                    Float(dataPoint.position.x),
                    Float(dataPoint.position.y),
                    Float(dataPoint.position.z)
                )
                
                // 为每个数据点创建独立的锚点，使用采集点的实际空间位置
                let anchor = AnchorEntity(world: position)
                let arrow = createMagneticFieldArrow(for: dataPoint, index: index)
                anchor.addChild(arrow)
                arView.scene.addAnchor(anchor)
                
                // 保存锚点引用，便于后续清除
                arrowAnchors.append(anchor)
                
                // 调试信息
                print("添加箭头 #\(index): 位置(\(position.x), \(position.y), \(position.z)), 磁场模长: \(dataPoint.magneticField.magnitude) μT")
            }
            
            // 如果数据点超过限制，在控制台输出提示
            if parent.fieldDataManager.collectedData.count > maxArrows {
                print("性能优化：只显示最新的 \(maxArrows) 个磁场箭头（共 \(parent.fieldDataManager.collectedData.count) 个数据点）")
            }
        }
        
        private func addTestArrow(to arView: ARView) {
            // 创建测试箭头：红色，固定大小，指向上方
            let testField = FieldDataPoint.MagneticField(x: 0, y: 50, z: 0)  // 50μT 向上
            let testAnchor = AnchorEntity(world: [0, 0, -0.5])  // 在相机前方0.5米
            
            let testArrow = createArrowWithHead(field: testField)
            
            // 强制红色材质便于识别
            var redMaterial = UnlitMaterial()
            redMaterial.color = .init(tint: UIColor.red)
            
            // 递归应用材质到所有子实体
            func applyMaterial(to entity: Entity) {
                if let modelEntity = entity as? ModelEntity {
                    modelEntity.model?.materials = [redMaterial]
                }
                for child in entity.children {
                    applyMaterial(to: child)
                }
            }
            applyMaterial(to: testArrow)
            
            testAnchor.addChild(testArrow)
            arView.scene.addAnchor(testAnchor)
            arrowAnchors.append(testAnchor)
            
            print("添加测试箭头：红色，指向Y轴正方向，位置(0, 0, -0.5)")
        }
        
        private func createMagneticFieldArrow(for dataPoint: FieldDataPoint, index: Int) -> ModelEntity {
            // 创建带有箭头头部的完整箭头
            let arrowEntity = createArrowWithHead(field: dataPoint.worldMagneticField)  // 使用世界坐标系磁场
            
            // 箭头位置设为原点，因为已经通过锚点定位到正确的空间位置
            arrowEntity.position = SIMD3<Float>(0, 0, 0)
            
            // 设置旋转以指向磁场方向（世界坐标系下的方向）
            let fieldDirection = dataPoint.worldMagneticField.normalized  // 使用世界坐标系磁场方向
            let rotation = calculateRotationFromMagnitude(for: fieldDirection)
            arrowEntity.orientation = rotation
            
            // 调试输出
            let deviceField = dataPoint.magneticField
            let worldField = dataPoint.worldMagneticField
            print("箭头 #\(index): 设备磁场(\(deviceField.x), \(deviceField.y), \(deviceField.z)) -> " +
                  "世界磁场(\(worldField.x), \(worldField.y), \(worldField.z))")
            
            return arrowEntity
        }
        
        private func createLightweightArrowMesh(field: FieldDataPoint.MagneticField) -> MeshResource {
            // 根据磁场模长调整箭头大小
            let magnitude = field.magnitude
            let normalizedMagnitude = min(magnitude / 100.0, 1.0)  // 适应 μT 单位
            let totalLength = Float(0.1 + normalizedMagnitude * 0.3)  // 0.1-0.4米，增大范围便于观察
            let radius = totalLength * 0.15  // 调整比例
            
            // 创建箭头主体（圆柱体，占总长度的70%）
            let shaftLength = totalLength * 0.7
            let shaftMesh = MeshResource.generateCylinder(height: shaftLength, radius: radius)
            
            return shaftMesh
        }
        
        private func createArrowWithHead(field: FieldDataPoint.MagneticField) -> ModelEntity {
            // 根据磁场模长调整箭头大小
            let magnitude = field.magnitude
            let normalizedMagnitude = min(magnitude / 100.0, 1.0)
            let totalLength = Float(0.1 + normalizedMagnitude * 0.3)  // 0.1-0.4米
            let radius = totalLength * 0.15
            
            // 创建根节点
            let arrowGroup = ModelEntity()
            
            // 箭头主体（圆柱体）
            let shaftLength = totalLength * 0.7
            let shaftMesh = MeshResource.generateCylinder(height: shaftLength, radius: radius)
            let material = createPerformantMaterial(for: field)
            let shaftEntity = ModelEntity(mesh: shaftMesh, materials: [material])
            shaftEntity.position = SIMD3<Float>(0, 0, 0)  // 主体在中心
            
            // 箭头头部（圆锥体）
            let headLength = totalLength * 0.3
            let headRadius = radius * 2.5  // 头部更宽
            let headMesh = MeshResource.generateCone(height: headLength, radius: headRadius)
            let headEntity = ModelEntity(mesh: headMesh, materials: [material])
            headEntity.position = SIMD3<Float>(0, (shaftLength + headLength) * 0.5, 0)  // 头部在顶端
            
            arrowGroup.addChild(shaftEntity)
            arrowGroup.addChild(headEntity)
            
            return arrowGroup
        }
        
        private func createPerformantMaterial(for field: FieldDataPoint.MagneticField) -> RealityFoundation.Material {
            let magnitude = field.magnitude
            let normalizedMagnitude = Float(min(magnitude / 100.0, 1.0))  // 转换为 Float
            
            // 创建基于模长的颜色梯度
            let color = createMagnitudeGradientColor(normalizedMagnitude)
            
            // 使用轻量级的未着色材质
            var material = UnlitMaterial()  // 不需要光照计算，性能更好
            material.color = .init(tint: color)
            
            return material
        }
        
        private func createMagnitudeGradientColor(_ normalizedMagnitude: Float) -> UIColor {
            // 创建从蓝色到红色的渐变，表示磁场强度
            let clampedMagnitude = max(0.0, min(1.0, normalizedMagnitude))
            
            if clampedMagnitude < 0.33 {
                // 弱磁场：蓝色到青色
                let ratio = clampedMagnitude / 0.33
                return UIColor(
                    red: 0.0,
                    green: CGFloat(ratio * 0.5),
                    blue: 1.0,
                    alpha: 0.9
                )
            } else if clampedMagnitude < 0.66 {
                // 中等磁场：青色到黄色
                let ratio = (clampedMagnitude - 0.33) / 0.33
                return UIColor(
                    red: CGFloat(ratio),
                    green: CGFloat(0.5 + ratio * 0.5),
                    blue: CGFloat(1.0 - ratio),
                    alpha: 0.9
                )
            } else {
                // 强磁场：黄色到红色
                let ratio = (clampedMagnitude - 0.66) / 0.34
                return UIColor(
                    red: 1.0,
                    green: CGFloat(1.0 - ratio),
                    blue: 0.0,
                    alpha: 0.9
                )
            }
        }
        
        private func calculateRotationFromMagnitude(for fieldDirection: FieldDataPoint.MagneticField) -> simd_quatf {
            let defaultDirection = SIMD3<Float>(0, 1, 0)  // 圆柱体默认沿Y轴
            
            let targetDirection = normalize(SIMD3<Float>(
                Float(fieldDirection.x),
                Float(fieldDirection.y),
                Float(fieldDirection.z)
            ))
            
            // 防止零向量
            let magnitude = length(targetDirection)
            if magnitude < 0.001 {
                return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
            }
            
            let normalizedTarget = targetDirection / magnitude
            
            let rotationAxis = cross(defaultDirection, normalizedTarget)
            let dot_product = dot(defaultDirection, normalizedTarget)
            let rotationAngle = acos(max(-1.0, min(1.0, dot_product)))
            
            if length(rotationAxis) < 0.001 {
                // 平行或反平行的情况
                if dot_product > 0 {
                    return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
                } else {
                    return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
                }
            }
            
            let normalizedAxis = normalize(rotationAxis)
            return simd_quatf(angle: rotationAngle, axis: normalizedAxis)
        }
    }
}
