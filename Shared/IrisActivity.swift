import Foundation
import ActivityKit

/// La "Actividad en vivo" de Iris: la tarjeta grande con tus tareas
/// en la pantalla de bloqueo y en la Dynamic Island.
/// La app le manda las tareas directamente, sin espacio compartido.
struct IrisTasksAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var tasks: [String]
        var pending: Int
    }
}
