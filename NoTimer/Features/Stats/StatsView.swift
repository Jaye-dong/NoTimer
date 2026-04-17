import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "统计尚未实现",
                systemImage: "chart.bar.xaxis",
                description: Text("M6 里程碑上线日/周/月按分类的时间分布图表")
            )
            .navigationTitle("统计")
        }
    }
}

#Preview {
    StatsView()
}
