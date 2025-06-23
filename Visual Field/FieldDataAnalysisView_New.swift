import SwiftUI
import Charts

#if canImport(UIKit)
import UIKit
#endif

struct FieldDataAnalysisView: View {
    let fieldData: [FieldDataPoint]
    @Environment(\.dismiss) private var dismiss
    @State private var showWorldCoordinates = true  // 默认显示世界坐标系数据
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 坐标系选择器
                    CoordinateSystemPicker(showWorldCoordinates: $showWorldCoordinates)
                    
                    // 统计信息卡片
                    StatisticsCardView(fieldData: fieldData, showWorldCoordinates: showWorldCoordinates)
                    
                    // 磁场强度图表
                    if #available(iOS 16.0, *) {
                        MagnitudeChartView(fieldData: fieldData, showWorldCoordinates: showWorldCoordinates)
                    }
                    
                    // 3D 磁场分量图表
                    if #available(iOS 16.0, *) {
                        ComponentsChartView(fieldData: fieldData, showWorldCoordinates: showWorldCoordinates)
                    }
                    
                    // 数据点列表
                    DataPointsListView(fieldData: fieldData, showWorldCoordinates: showWorldCoordinates)
                }
                .padding()
            }
            .navigationTitle("磁场数据分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CoordinateSystemPicker: View {
    @Binding var showWorldCoordinates: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            Text("坐标系选择")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("坐标系", selection: $showWorldCoordinates) {
                Text("设备坐标系").tag(false)
                Text("世界坐标系").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text(showWorldCoordinates ? 
                 "显示转换到ARKit世界坐标系的磁场数据" : 
                 "显示设备传感器原始磁场数据")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
    }
}

struct StatisticsCardView: View {
    let fieldData: [FieldDataPoint]
    let showWorldCoordinates: Bool
    
    var statistics: (min: Double, max: Double, average: Double, count: Int) {
        guard !fieldData.isEmpty else { return (0, 0, 0, 0) }
        
        let magnitudes = fieldData.map { dataPoint in
            showWorldCoordinates ? dataPoint.worldMagneticField.magnitude : dataPoint.magneticField.magnitude
        }
        let min = magnitudes.min() ?? 0
        let max = magnitudes.max() ?? 0
        let average = magnitudes.reduce(0, +) / Double(magnitudes.count)
        
        return (min, max, average, fieldData.count)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text("数据统计")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                StatisticItem(title: "数据点数", value: "\(statistics.count)", color: .blue)
                StatisticItem(title: "平均强度", value: String(format: "%.1f μT", statistics.average), color: .green)
                StatisticItem(title: "最小强度", value: String(format: "%.1f μT", statistics.min), color: .orange)
                StatisticItem(title: "最大强度", value: String(format: "%.1f μT", statistics.max), color: .red)
            }
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 16.0, *)
struct MagnitudeChartView: View {
    let fieldData: [FieldDataPoint]
    let showWorldCoordinates: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("磁场强度变化")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(fieldData.indices, id: \.self) { (index: Int) in
                let dataPoint = fieldData[index]
                let magnitude = showWorldCoordinates ? 
                    dataPoint.worldMagneticField.magnitude : 
                    dataPoint.magneticField.magnitude
                
                LineMark(
                    x: .value("时间", index),
                    y: .value("强度", magnitude)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 200)
            .chartYAxisLabel("磁场强度 (μT)")
            .chartXAxisLabel("数据点序号")
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

@available(iOS 16.0, *)
struct ComponentsChartView: View {
    let fieldData: [FieldDataPoint]
    let showWorldCoordinates: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("磁场分量变化")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(fieldData.indices, id: \.self) { (index: Int) in
                let dataPoint = fieldData[index]
                let field = showWorldCoordinates ? dataPoint.worldMagneticField : dataPoint.magneticField
                
                LineMark(
                    x: .value("时间", index),
                    y: .value("X", field.x)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                LineMark(
                    x: .value("时间", index),
                    y: .value("Y", field.y)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                LineMark(
                    x: .value("时间", index),
                    y: .value("Z", field.z)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 200)
            .chartYAxisLabel("磁场强度 (μT)")
            .chartXAxisLabel("数据点序号")
            .chartForegroundStyleScale([
                "X": .red,
                "Y": .green, 
                "Z": .blue
            ])
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct DataPointsListView: View {
    let fieldData: [FieldDataPoint]
    let showWorldCoordinates: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("数据点详情 (前 10 个)")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 10) {
                ForEach(Array(fieldData.prefix(10).enumerated()), id: \.offset) { (index: Int, dataPoint: FieldDataPoint) in
                    DataPointRowView(
                        index: index,
                        dataPoint: dataPoint,
                        showWorldCoordinates: showWorldCoordinates
                    )
                }
            }
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct DataPointRowView: View {
    let index: Int
    let dataPoint: FieldDataPoint
    let showWorldCoordinates: Bool
    
    var body: some View {
        let field = showWorldCoordinates ? dataPoint.worldMagneticField : dataPoint.magneticField
        
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("数据点 #\(index + 1)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.1f μT", field.magnitude))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("位置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "(%.2f, %.2f, %.2f)", 
                               dataPoint.position.x, 
                               dataPoint.position.y, 
                               dataPoint.position.z))
                        .font(.caption)
                        .fontFamily(.monospaced)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("磁场分量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "(%.1f, %.1f, %.1f)", 
                               field.x, field.y, field.z))
                        .font(.caption)
                        .fontFamily(.monospaced)
                }
            }
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(8)
    }
}

// MARK: - 预览
struct FieldDataAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = [
            FieldDataPoint(
                timestamp: Date(),
                position: FieldDataPoint.Position(x: 0, y: 0, z: 0),
                magneticField: FieldDataPoint.MagneticField(x: 25.5, y: -15.2, z: 48.7),
                deviceOrientation: nil
            ),
            FieldDataPoint(
                timestamp: Date().addingTimeInterval(1),
                position: FieldDataPoint.Position(x: 0.1, y: 0, z: 0.1),
                magneticField: FieldDataPoint.MagneticField(x: 26.1, y: -14.8, z: 49.2),
                deviceOrientation: nil
            )
        ]
        
        FieldDataAnalysisView(fieldData: sampleData)
    }
}
