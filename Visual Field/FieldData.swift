import Foundation
import CoreMotion
import CoreLocation
import simd

#if canImport(ARKit)
import ARKit
#endif

// MARK: - 磁场数据点结构
struct FieldDataPoint: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let position: Position
    let magneticField: MagneticField
    let deviceOrientation: DeviceOrientation?  // 设备方向信息，用于坐标转换
    
    struct Position: Codable {
        let x: Double
        let y: Double
        let z: Double
    }
    
    struct MagneticField: Codable {
        let x: Double  // μT (微特斯拉)
        let y: Double
        let z: Double
        
        var magnitude: Double {
            sqrt(x * x + y * y + z * z)
        }
        
        var normalized: MagneticField {
            let mag = magnitude
            guard mag > 0 else { return MagneticField(x: 0, y: 0, z: 1) }
            return MagneticField(x: x / mag, y: y / mag, z: z / mag)
        }
    }
    
    struct DeviceOrientation: Codable {
        let quaternion: [Double]  // 四元数 [x, y, z, w]
        let matrix: [Double]      // 3x3旋转矩阵，用于磁场矢量转换
    }
    
    // 将设备坐标系的磁场矢量转换到世界坐标系
    var worldMagneticField: MagneticField {
        guard let orientation = deviceOrientation else {
            return magneticField  // 没有设备方向信息，返回原始数据
        }
        
        // 使用旋转矩阵转换磁场矢量
        let matrix = orientation.matrix
        let deviceField = SIMD3<Double>(magneticField.x, magneticField.y, magneticField.z)
        
        // 应用旋转矩阵 (3x3)
        let worldX = matrix[0] * deviceField.x + matrix[1] * deviceField.y + matrix[2] * deviceField.z
        let worldY = matrix[3] * deviceField.x + matrix[4] * deviceField.y + matrix[5] * deviceField.z  
        let worldZ = matrix[6] * deviceField.x + matrix[7] * deviceField.y + matrix[8] * deviceField.z
        
        return MagneticField(x: worldX, y: worldY, z: worldZ)
    }
}

// MARK: - 磁场数据管理器
class FieldDataManager: ObservableObject {
    @Published var isCollecting = false
    @Published var collectedData: [FieldDataPoint] = []
    @Published var currentMagneticField: FieldDataPoint.MagneticField?
    
    #if os(iOS)
    private let motionManager = CMMotionManager()
    #endif
    
    #if canImport(ARKit) && os(iOS)
    var arSession: ARSession?
    #endif
    
    private var currentPosition = FieldDataPoint.Position(x: 0, y: 0, z: 0)
    private var collectionTimer: Timer?
    private var lastMagneticField: FieldDataPoint.MagneticField?
    
    // 采集参数
    private let collectionInterval: TimeInterval = 0.5  // 每0.5秒采集一次
    private let movementThreshold: Double = 0.1  // 移动阈值，用于检测位置变化
    
    // 数据平滑参数
    private let smoothingFactor: Double = 0.3
    private var smoothedField: FieldDataPoint.MagneticField?
    
    init() {
        #if os(iOS)
        setupMotionManager()
        #endif
    }
    
    deinit {
        stopCollecting()
    }
    
    // MARK: - 权限请求
    func requestPermissions() {
        print("请求传感器权限...")
    }
    
    // MARK: - 运动管理器设置
    #if os(iOS)
    private func setupMotionManager() {
        guard motionManager.isMagnetometerAvailable else {
            print("磁力计不可用")
            return
        }
        
        motionManager.magnetometerUpdateInterval = 0.1  // 100ms 更新间隔
        motionManager.deviceMotionUpdateInterval = 0.1  // 同时启用设备运动更新
    }
    #endif
    
    // MARK: - 开始采集
    func startCollecting() {
        guard !isCollecting else { return }
        
        isCollecting = true
        
        #if os(iOS)
        startMotionUpdates()
        #endif
        
        // 开始定时采集数据点
        collectionTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            self?.collectDataPoint()
        }
        
        print("开始磁场数据采集")
    }
    
    #if os(iOS)
    private func startMotionUpdates() {
        // 启动磁力计更新
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let magnetometerData = data else { return }
            
            // CMMagnetometerData.magneticField 的单位已经是微特斯拉 (μT)，无需转换
            let rawField = FieldDataPoint.MagneticField(
                x: magnetometerData.magneticField.x,
                y: magnetometerData.magneticField.y,
                z: magnetometerData.magneticField.z
            )
            
            // 应用数据平滑
            let smoothed = self.applySmoothingFilter(to: rawField)
            
            DispatchQueue.main.async {
                self.currentMagneticField = smoothed
            }
        }
        
        // 启动设备运动更新以获取方向信息
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] (motion, error) in
            guard let self = self, let deviceMotion = motion else { return }
            
            // 获取设备相对于世界坐标系的方向
            let attitude = deviceMotion.attitude
            self.updateDeviceOrientation(from: attitude)
        }
    }
    #endif
    
    // MARK: - 数据平滑处理
    private func applySmoothingFilter(to field: FieldDataPoint.MagneticField) -> FieldDataPoint.MagneticField {
        guard let previous = smoothedField else {
            smoothedField = field
            return field
        }
        
        // 指数平滑滤波
        let smoothed = FieldDataPoint.MagneticField(
            x: previous.x * (1 - smoothingFactor) + field.x * smoothingFactor,
            y: previous.y * (1 - smoothingFactor) + field.y * smoothingFactor,
            z: previous.z * (1 - smoothingFactor) + field.z * smoothingFactor
        )
        
        smoothedField = smoothed
        return smoothed
    }
    
    private var currentDeviceOrientation: FieldDataPoint.DeviceOrientation?
    
    #if os(iOS)
    private func updateDeviceOrientation(from attitude: CMAttitude) {
        // 获取旋转矩阵
        let rotationMatrix = attitude.rotationMatrix
        
        // 将CMRotationMatrix转换为数组格式 (行优先存储)
        let matrix = [
            rotationMatrix.m11, rotationMatrix.m12, rotationMatrix.m13,
            rotationMatrix.m21, rotationMatrix.m22, rotationMatrix.m23,
            rotationMatrix.m31, rotationMatrix.m32, rotationMatrix.m33
        ]
        
        // 获取四元数
        let quaternion = [
            attitude.quaternion.x,
            attitude.quaternion.y, 
            attitude.quaternion.z,
            attitude.quaternion.w
        ]
        
        currentDeviceOrientation = FieldDataPoint.DeviceOrientation(
            quaternion: quaternion,
            matrix: matrix
        )
    }
    #endif
    
    // MARK: - 停止采集
    func stopCollecting() {
        guard isCollecting else { return }
        
        isCollecting = false
        
        #if os(iOS)
        motionManager.stopMagnetometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        #endif
        
        collectionTimer?.invalidate()
        collectionTimer = nil
        
        print("停止磁场数据采集，共采集 \(collectedData.count) 个数据点")
    }
    
    // MARK: - 采集数据点
    private func collectDataPoint() {
        guard let magneticField = currentMagneticField else { return }
        
        // 更新位置信息
        updateCurrentPosition()
        
        let dataPoint = FieldDataPoint(
            timestamp: Date(),
            position: currentPosition,
            magneticField: magneticField,
            deviceOrientation: currentDeviceOrientation
        )
        
        DispatchQueue.main.async {
            self.collectedData.append(dataPoint)
            
            // 性能优化：限制数据点数量
            if self.collectedData.count > 1000 {
                self.collectedData.removeFirst(100)  // 移除最老的100个点
            }
        }
        
        print("采集数据点: 位置(\(currentPosition.x), \(currentPosition.y), \(currentPosition.z)), " +
              "磁场模长: \(magneticField.magnitude) μT, " +
              "世界坐标磁场模长: \(dataPoint.worldMagneticField.magnitude) μT")
    }
    
    // MARK: - 更新当前位置
    private func updateCurrentPosition() {
        #if canImport(ARKit) && os(iOS)
        // 如果有ARKit会话，使用真实的相机位置
        if let arSession = arSession,
           let currentFrame = arSession.currentFrame {
            let cameraTransform = currentFrame.camera.transform
            let position = cameraTransform.columns.3  // 提取位置向量
            
            currentPosition = FieldDataPoint.Position(
                x: Double(position.x),
                y: Double(position.y),
                z: Double(position.z)
            )
        } else {
            // 后备方案：使用模拟位置
            simulatePositionUpdate()
        }
        #else
        // 非iOS平台或ARKit不可用时的后备方案
        simulatePositionUpdate()
        #endif
    }
    
    private func simulatePositionUpdate() {
        // 模拟位置变化用于测试
        let timeOffset = Date().timeIntervalSince1970
        currentPosition = FieldDataPoint.Position(
            x: sin(timeOffset * 0.1) * 2.0,
            y: 0.5,  // 稍微抬高避免与地面重叠
            z: cos(timeOffset * 0.1) * 2.0
        )
    }
    
    // MARK: - 清除数据
    func clearData() {
        collectedData.removeAll()
        print("已清除所有采集数据")
    }
    
    // MARK: - 数据分析
    func getFieldStatistics() -> (min: Double, max: Double, average: Double) {
        guard !collectedData.isEmpty else { return (0, 0, 0) }
        
        let magnitudes = collectedData.map { $0.magneticField.magnitude }
        let min = magnitudes.min() ?? 0
        let max = magnitudes.max() ?? 0
        let average = magnitudes.reduce(0, +) / Double(magnitudes.count)
        
        return (min, max, average)
    }
    
    // MARK: - 导出数据
    func exportData() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(collectedData)
        } catch {
            print("导出数据失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 导入数据
    func importData(from data: Data) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedData = try decoder.decode([FieldDataPoint].self, from: data)
            
            DispatchQueue.main.async {
                self.collectedData = importedData
            }
            
            print("成功导入 \(importedData.count) 个数据点")
        } catch {
            print("导入数据失败: \(error)")
        }
    }
}
