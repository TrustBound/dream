//// The system of record of the notes: an actor that keeps them in memory.
//// A real app keeps them in its database. The search index is a copy of
//// this store, so the store answers first and the index follows.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result

/// A note, with the ID that the store gave it
pub type Note {
  Note(id: Int, title: String, body: String)
}

/// The title and the body of a note that a client sends
pub type Draft {
  Draft(title: String, body: String)
}

pub type StoreError {
  /// No note has this ID
  NoteNotFound(id: Int)
  /// The store did not answer within the wait time
  StoreDidNotAnswer
}

/// The note store. Keep it in the services of the app.
pub opaque type Store {
  Store(subject: Subject(Message))
}

type Message {
  Create(draft: Draft, reply: Subject(Result(Note, StoreError)))
  Update(id: Int, draft: Draft, reply: Subject(Result(Note, StoreError)))
  Delete(id: Int, reply: Subject(Result(Note, StoreError)))
  Stop
}

type State {
  State(next_id: Int, notes: Dict(Int, Note))
}

/// How long a request waits for the store, in milliseconds
const wait_milliseconds = 1000

/// Starts an empty store. The first note gets the ID 1.
pub fn start() -> Result(Store, actor.StartError) {
  actor.new(State(next_id: 1, notes: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { Store(subject: started.data) })
}

/// Stops the store. Its notes go away with it.
pub fn stop(store: Store) -> Nil {
  process.send(store.subject, Stop)
}

/// Keeps a new note, and gives it with its ID
pub fn create(store: Store, draft: Draft) -> Result(Note, StoreError) {
  ask(store, Create(draft:, reply: _))
}

/// Changes the title and the body of the note with `id`
pub fn update(store: Store, id: Int, draft: Draft) -> Result(Note, StoreError) {
  ask(store, Update(id:, draft:, reply: _))
}

/// Removes the note with `id`, and gives the note that it removed
pub fn delete(store: Store, id: Int) -> Result(Note, StoreError) {
  ask(store, Delete(id:, reply: _))
}

fn ask(
  store: Store,
  message: fn(Subject(Result(Note, StoreError))) -> Message,
) -> Result(Note, StoreError) {
  let reply = process.new_subject()
  process.send(store.subject, message(reply))
  process.receive(reply, within: wait_milliseconds)
  |> result.replace_error(StoreDidNotAnswer)
  |> result.flatten
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Create(draft:, reply:) -> {
      let note = Note(id: state.next_id, title: draft.title, body: draft.body)
      process.send(reply, Ok(note))
      actor.continue(State(
        next_id: state.next_id + 1,
        notes: dict.insert(state.notes, note.id, note),
      ))
    }
    Update(id:, draft:, reply:) -> {
      let found =
        dict.get(state.notes, id)
        |> result.replace_error(NoteNotFound(id:))
        |> result.replace(Note(id:, title: draft.title, body: draft.body))
      process.send(reply, found)
      actor.continue(keep(state, found))
    }
    Delete(id:, reply:) -> {
      let found =
        dict.get(state.notes, id) |> result.replace_error(NoteNotFound(id:))
      process.send(reply, found)
      actor.continue(State(..state, notes: dict.delete(state.notes, id)))
    }
    Stop -> actor.stop()
  }
}

/// The state with the changed note in it. A note that is not found
/// changes nothing.
fn keep(state: State, found: Result(Note, StoreError)) -> State {
  found
  |> result.map(fn(note) {
    State(..state, notes: dict.insert(state.notes, note.id, note))
  })
  |> result.unwrap(state)
}
