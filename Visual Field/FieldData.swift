import Foundation
import CoreMotion
import CoreLocation
import ARKit

// MARK: - 磁场数据点结构
struct FieldDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let position: Position
    let magneticField: MagneticField
    
    // 自定义编码键，排除 id 属性
    enum CodingKeys: String, CodingKey {
        case timestamp
        case position
        case magneticField
    }
    
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
}

// MARK: - 磁场数据管理器
class FieldDataManager: ObservableObject {
    @Published var isCollecting = false
    @Published var collectedData: [FieldDataPoint] = []
    @Published var currentMagneticField: FieldDataPoint.MagneticField?
    
    private let motionManager = CMMotionManager()
    private var currentPosition = FieldDataPoint.Position(x: 0, y: 0, z: 0)
    private var collectionTimer: Timer?
    
    // AR 会话引用，用于获取真实的设备位置和方向
    weak var arSession: ARSession?
    private var currentDeviceTransform = matrix_identity_float4x4
    
    // 采集参数
    private let collectionInterval: TimeInterval = 0.5  // 每0.5秒采集一次
    private let movementThreshold: Double = 0.1  // 移动阈值，用于检测位置变化
    
    init() {
        setupMotionManager()
    }
    
    deinit {
        stopCollecting()
    }
    
    // MARK: - 权限请求
    func requestPermissions() {
        // 这里可以添加位置权限请求等
        print("请求传感器权限...")
    }
    
    // MARK: - 运动管理器设置
    private func setupMotionManager() {
        guard motionManager.isMagnetometerAvailable else {
            print("磁力计不可用")
            return
        }
        
        motionManager.magnetometerUpdateInterval = 0.1  // 100ms 更新间隔
    }
    
    // MARK: - 开始采集
    func startCollecting() {
        guard !isCollecting else { return }
        
        isCollecting = true
        
        // 开始磁力计更新
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let magnetometerData = data else { return }
            
            // 转换为微特斯拉 (μT)
            let magneticField = FieldDataPoint.MagneticField(
                x: magnetometerData.magneticField.x,  // μT
                y: magnetometerData.magneticField.y,
                z: magnetometerData.magneticField.z
            )
            
            DispatchQueue.main.async {
                self.currentMagneticField = magneticField
            }
        }
        
        // 开始定时采集数据点
        collectionTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            self?.collectDataPoint()
        }
        
        print("开始磁场数据采集")
    }
    
    // MARK: - 停止采集
    func stopCollecting() {
        guard isCollecting else { return }
        
        isCollecting = false
        motionManager.stopMagnetometerUpdates()
        collectionTimer?.invalidate()
        collectionTimer = nil
        
        print("停止磁场数据采集，共采集 \(collectedData.count) 个数据点")
    }
    
    // MARK: - 采集数据点
    private func collectDataPoint() {
        guard let magneticField = currentMagneticField else { return }
        
        // 从 AR 会话获取真实的设备位置和方向
        updateCurrentPositionFromAR()
        
        // 将设备坐标系下的磁场矢量转换到世界坐标系
        let worldMagneticField = transformMagneticFieldToWorld(magneticField)
        
        let dataPoint = FieldDataPoint(
            timestamp: Date(),
            position: currentPosition,
            magneticField: worldMagneticField
        )
        
        DispatchQueue.main.async {
            self.collectedData.append(dataPoint)
        }
    }
    
    // MARK: - 从 AR 会话更新当前位置
    private func updateCurrentPositionFromAR() {
        guard let arSession = arSession,
              let currentFrame = arSession.currentFrame else {
            // 如果 AR 不可用，使用模拟位置
            updateCurrentPositionSimulated()
            return
        }
        
        // 获取设备在世界坐标系中的变换矩阵
        let cameraTransform = currentFrame.camera.transform
        currentDeviceTransform = cameraTransform
        
        // 提取位置
        let position = cameraTransform.columns.3
        currentPosition = FieldDataPoint.Position(
            x: Double(position.x),
            y: Double(position.y),
            z: Double(position.z)
        )
    }
    
    // MARK: - 将磁场矢量从设备坐标系转换到世界坐标系
    private func transformMagneticFieldToWorld(_ deviceMagneticField: FieldDataPoint.MagneticField) -> FieldDataPoint.MagneticField {
        // 设备坐标系下的磁场矢量
        let deviceVector = SIMD3<Float>(
            Float(deviceMagneticField.x),
            Float(deviceMagneticField.y),
            Float(deviceMagneticField.z)
        )
        
        // 使用设备变换矩阵的旋转部分转换矢量
        let rotationMatrix = matrix_float3x3(
            currentDeviceTransform.columns.0.xyz,
            currentDeviceTransform.columns.1.xyz,
            currentDeviceTransform.columns.2.xyz
        )
        
        let worldVector = rotationMatrix * deviceVector
        
        return FieldDataPoint.MagneticField(
            x: Double(worldVector.x),
            y: Double(worldVector.y),
            z: Double(worldVector.z)
        )
    }
    
    // MARK: - 模拟位置更新（作为后备方案）
    private func updateCurrentPositionSimulated() {
        // 这里是简化的位置更新逻辑
        // 实际应用中应该集成 ARKit 来获取精确的 3D 位置
        let timeOffset = Date().timeIntervalSince1970
        currentPosition = FieldDataPoint.Position(
            x: sin(timeOffset * 0.1) * 2.0,  // 模拟 X 轴移动
            y: 0.0,                          // Y 轴固定
            z: cos(timeOffset * 0.1) * 2.0   // 模拟 Z 轴移动
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

// MARK: - SIMD 扩展
extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
