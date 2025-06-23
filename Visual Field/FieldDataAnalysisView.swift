import SwiftUI
import Charts

struct FieldDataAnalysisView: View {
    let fieldData: [FieldDataPoint]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计信息卡片
                    StatisticsCardView(fieldData: fieldData)
                    
                    // 磁场强度图表
                    if #available(iOS 16.0, *) {
                        MagnitudeChartView(fieldData: fieldData)
                    }
                    
                    // 3D 磁场分量图表
                    if #available(iOS 16.0, *) {
                        ComponentsChartView(fieldData: fieldData)
                    }
                    
                    // 数据点列表
                    DataPointsListView(fieldData: fieldData)
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

struct StatisticsCardView: View {
    let fieldData: [FieldDataPoint]
    
    var statistics: (min: Double, max: Double, average: Double, count: Int) {
        guard !fieldData.isEmpty else { return (0, 0, 0, 0) }
        
        let magnitudes = fieldData.map { $0.magneticField.magnitude }
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
        .background(Color(.systemBackground))
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("磁场强度变化")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(Array(fieldData.enumerated()), id: \.offset) { index, dataPoint in
                LineMark(
                    x: .value("时间", index),
                    y: .value("强度", dataPoint.magneticField.magnitude)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 200)
            .chartYAxisLabel("磁场强度 (μT)")
            .chartXAxisLabel("数据点序号")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

@available(iOS 16.0, *)
struct ComponentsChartView: View {
    let fieldData: [FieldDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("磁场分量变化")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(Array(fieldData.enumerated()), id: \.offset) { index, dataPoint in
                LineMark(
                    x: .value("时间", index),
                    y: .value("X", dataPoint.magneticField.x)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                LineMark(
                    x: .value("时间", index),
                    y: .value("Y", dataPoint.magneticField.y)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                LineMark(
                    x: .value("时间", index),
                    y: .value("Z", dataPoint.magneticField.z)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 200)
            .chartYAxisLabel("磁场分量 (μT)")
            .chartXAxisLabel("数据点序号")
            
            // 图例
            HStack(spacing: 20) {
                LegendItem(color: .red, label: "X 轴")
                LegendItem(color: .green, label: "Y 轴")
                LegendItem(color: .blue, label: "Z 轴")
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DataPointsListView: View {
    let fieldData: [FieldDataPoint]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("数据点详情")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(Array(fieldData.prefix(10).enumerated()), id: \.offset) { index, dataPoint in
                        DataPointRowView(dataPoint: dataPoint, index: index)
                    }
                    
                    if fieldData.count > 10 {
                        Text("... 还有 \(fieldData.count - 10) 个数据点")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct DataPointRowView: View {
    let dataPoint: FieldDataPoint
    let index: Int
    
    var body: some View {
        HStack {
            Text("#\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("强度: \(String(format: "%.1f", dataPoint.magneticField.magnitude)) μT")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(dataPoint.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    ComponentValueView(label: "X", value: dataPoint.magneticField.x, color: .red)
                    ComponentValueView(label: "Y", value: dataPoint.magneticField.y, color: .green)
                    ComponentValueView(label: "Z", value: dataPoint.magneticField.z, color: .blue)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct ComponentValueView: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
                .fontWeight(.medium)
            
            Text(String(format: "%.1f", value))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let sampleData = [
        FieldDataPoint(
            timestamp: Date(),
            position: FieldDataPoint.Position(x: 0, y: 0, z: 0),
            magneticField: FieldDataPoint.MagneticField(x: 25.5, y: -15.2, z: 48.7)
        ),
        FieldDataPoint(
            timestamp: Date().addingTimeInterval(1),
            position: FieldDataPoint.Position(x: 0.1, y: 0, z: 0.1),
            magneticField: FieldDataPoint.MagneticField(x: 27.1, y: -14.8, z: 49.2)
        )
    ]
    
    FieldDataAnalysisView(fieldData: sampleData)
}
