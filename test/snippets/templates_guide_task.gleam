//// Templates guide: the task and tag types the templates show

pub type Tag {
  Tag(name: String)
}

pub type Task {
  Task(id: Int, title: String, completed: Bool, tags: List(Tag))
}
