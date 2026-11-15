//// Architecture reference: the Task domain type
////
//// The type that the model, the view and the controller share.

pub type Task {
  Task(id: Int, title: String, completed: Bool)
}
