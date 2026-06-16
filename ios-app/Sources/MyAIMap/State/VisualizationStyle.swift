import Foundation

/// On-screen map rendering style. iOS ships the RealityKit `.galaxy`
/// today; the rest mirror the web playground variant ids so the picker
/// is ready for future native renderers. Non-shipped styles report
/// `available == false` and render as disabled rows — a visible control
/// that does nothing is worse than none (review NEW-6).
enum VisualizationStyle: String, CaseIterable, Identifiable, Sendable {
    case galaxy        // RealityKit cosmic map — the shipping default
    case brain         // web "BrainGraph"
    case neural        // web "NeuralNet" / "NeuralUniverse"
    case force3D       // web "Force3D"

    var id: String { rawValue }

    /// Whether iOS can currently render this style.
    var available: Bool { self == .galaxy }

    func title(_ l: AppLanguage) -> String {
        switch self {
        case .galaxy:  return l == .ru ? "Галактика" : "Galaxy"
        case .brain:   return l == .ru ? "Мозг" : "Brain"
        case .neural:  return l == .ru ? "Нейросеть" : "Neural"
        case .force3D: return l == .ru ? "3D-граф" : "3D Force"
        }
    }
}
