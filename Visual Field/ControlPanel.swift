//
//  ControlPanel.swift
//  Visual Field
//
//  Created by Leo Li on 2025/6/19.
//

import SwiftUI
import simd

struct ControlPanel: View {
    @ObservedObject var magneticFieldManager: MagneticFieldManager
    @ObservedObject var dataCollection: MagneticFieldDataCollection
    @Binding var visualizationType: MagneticFieldVisualizer.VisualizationType
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态信息
            StatusCard(
                magneticFieldManager: magneticFieldManager,
                dataCollection: dataCollection
            )
            
            // 采集控制
            RecordingControls(
                magneticFieldManager: magneticFieldManager,
                dataCollection: dataCollection
            )
            
            // 可视化控制
            VisualizationControls(visualizationType: $visualizationType)
            
            // 数据管理
            DataManagementControls(dataCollection: dataCollection)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding()
    }
}

struct StatusCard: View {
    @ObservedObject var magneticFieldManager: MagneticFieldManager
    @ObservedObject var dataCollection: MagneticFieldDataCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: magneticFieldManager.isTracking ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(magneticFieldManager.isTracking ? .green : .red)
                Text("磁场追踪")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if magneticFieldManager.isTracking {
                VStack(alignment: .leading, spacing: 4) {
                    Text("位置: (\(String(format: "%.2f", magneticFieldManager.currentPosition.x)), \(String(format: "%.2f", magneticFieldManager.currentPosition.y)), \(String(format: "%.2f", magneticFieldManager.currentPosition.z)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("磁场: (\(String(format: "%.1f", magneticFieldManager.currentMagneticField.x)), \(String(format: "%.1f", magneticFieldManager.currentMagneticField.y)), \(String(format: "%.1f", magneticFieldManager.currentMagneticField.z))) µT")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("强度: \(String(format: "%.1f", length(magneticFieldManager.currentMagneticField))) µT")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Image(systemName: "chart.dots.scatter")
                    .foregroundColor(.blue)
                Text("数据点: \(dataCollection.dataPoints.count)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct RecordingControls: View {
    @ObservedObject var magneticFieldManager: MagneticFieldManager
    @ObservedObject var dataCollection: MagneticFieldDataCollection
    
    @State private var recordingTimer: Timer?
    @State private var recordingInterval: Double = 0.5 // 500ms间隔
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("数据采集")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack {
                Text("采集间隔: \(String(format: "%.1f", recordingInterval))s")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Slider(value: $recordingInterval, in: 0.1...2.0, step: 0.1)
                    .frame(width: 100)
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if dataCollection.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: dataCollection.isRecording ? "stop.circle.fill" : "record.circle")
                        Text(dataCollection.isRecording ? "停止采集" : "开始采集")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(dataCollection.isRecording ? Color.red : Color.green)
                    .cornerRadius(25)
                }
                
                Button(action: {
                    addSingleDataPoint()
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("添加点")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
                .disabled(!magneticFieldManager.isTracking)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private func startRecording() {
        guard magneticFieldManager.isTracking else { return }
        
        dataCollection.isRecording = true
        recordingTimer = Timer.scheduledTimer(withTimeInterval: recordingInterval, repeats: true) { _ in
            addSingleDataPoint()
        }
    }
    
    private func stopRecording() {
        dataCollection.isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func addSingleDataPoint() {
        guard let dataPoint = magneticFieldManager.getCurrentDataPoint() else { return }
        dataCollection.addDataPoint(dataPoint)
    }
}

struct VisualizationControls: View {
    @Binding var visualizationType: MagneticFieldVisualizer.VisualizationType
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("可视化模式")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach([
                    (MagneticFieldVisualizer.VisualizationType.vectors, "箭头", "arrow.up"),
                    (MagneticFieldVisualizer.VisualizationType.heatMap, "热力图", "circle.fill"),
                    (MagneticFieldVisualizer.VisualizationType.particles, "粒子", "sparkles")
                ], id: \.0.hashValue) { type, title, icon in
                    Button(action: {
                        visualizationType = type
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.title3)
                            Text(title)
                                .font(.caption)
                        }
                        .foregroundColor(visualizationType.hashValue == type.hashValue ? .blue : .gray)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            visualizationType.hashValue == type.hashValue ? 
                            Color.blue.opacity(0.2) : Color.clear
                        )
                        .cornerRadius(8)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct DataManagementControls: View {
    @ObservedObject var dataCollection: MagneticFieldDataCollection
    @State private var showingClearAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("数据管理")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if !dataCollection.dataPoints.isEmpty {
                let bounds = dataCollection.spatialBounds
                let fieldRange = dataCollection.fieldStrengthRange
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("空间范围: \(String(format: "%.2f", distance(bounds.min, bounds.max)))m")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("磁场范围: \(String(format: "%.1f", fieldRange.min))-\(String(format: "%.1f", fieldRange.max)) µT")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    // 导出数据功能
                    exportData()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(20)
                }
                .disabled(dataCollection.dataPoints.isEmpty)
                
                Button(action: {
                    showingClearAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清除")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(20)
                }
                .disabled(dataCollection.dataPoints.isEmpty)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .alert("清除数据", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                dataCollection.clearData()
            }
        } message: {
            Text("确定要清除所有已采集的磁场数据吗？此操作无法撤销。")
        }
    }
    
    private func exportData() {
        // 简化实现，实际应用中可以导出到文件
        let jsonData = try? JSONSerialization.data(withJSONObject: dataCollection.dataPoints.map { point in
            [
                "position": [point.position.x, point.position.y, point.position.z],
                "magneticField": [point.magneticField.x, point.magneticField.y, point.magneticField.z],
                "fieldStrength": point.fieldStrength,
                "timestamp": point.timestamp.timeIntervalSince1970
            ]
        })
        
        if let data = jsonData, let jsonString = String(data: data, encoding: .utf8) {
            print("导出的磁场数据:")
            print(jsonString)
        }
    }
}

// 扩展以支持哈希值比较
extension MagneticFieldVisualizer.VisualizationType: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .vectors:
            hasher.combine(0)
        case .heatMap:
            hasher.combine(1)
        case .particles:
            hasher.combine(2)
        }
    }
}
