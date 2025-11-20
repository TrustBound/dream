defmodule DatabaseSteps do
  use Cucumber.StepDefinition

  alias TestDB
  alias Postgrex

  step "I clear all test tables", _context do
    TestDB.clear_all_tables()
    %{}
  end

  step "a task exists with title {string}", %{args: [title]} = context do
    conn = TestDB.get_connection()

    # Insert a task into the database
    Postgrex.query!(
      conn,
      """
      INSERT INTO tasks (title, description, completed, priority, position, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
      RETURNING id
      """,
      [title, "Test description", false, 3, 1]
    )

    context
  end

  step "a project exists with name {string}", %{args: [name]} = context do
    conn = TestDB.get_connection()

    Postgrex.query!(
      conn,
      """
      INSERT INTO projects (name, description, color, created_at)
      VALUES ($1, $2, $3, NOW())
      RETURNING id
      """,
      [name, "Test project description", nil]
    )

    context
  end

  step "a tag exists with name {string}", %{args: [name]} = context do
    conn = TestDB.get_connection()

    Postgrex.query!(
      conn,
      """
      INSERT INTO tags (name, color)
      VALUES ($1, $2)
      RETURNING id
      """,
      [name, nil]
    )

    context
  end

  step "tag {string} is attached to task {string}", %{args: [tag_id_str, task_id_str]} = context do
    conn = TestDB.get_connection()
    tag_id = String.to_integer(tag_id_str)
    task_id = String.to_integer(task_id_str)

    Postgrex.query!(
      conn,
      """
      INSERT INTO task_tags (task_id, tag_id)
      VALUES ($1, $2)
      ON CONFLICT (task_id, tag_id) DO NOTHING
      """,
      [task_id, tag_id]
    )

    context
  end

  step "the task with id {int} should exist in the database with title {string}",
       %{args: [task_id, expected_title]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT title FROM tasks WHERE id = $1",
        [task_id]
      )

    case result.rows do
      [[title]] ->
        if title == expected_title do
          context
        else
          raise "Expected task #{task_id} to have title '#{expected_title}', got '#{title}'"
        end

      [] ->
        raise "Task #{task_id} does not exist in database"

      _ ->
        raise "Unexpected result when querying task #{task_id}"
    end
  end

  step "the task with id {int} should be completed",
       %{args: [task_id]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT completed FROM tasks WHERE id = $1",
        [task_id]
      )

    case result.rows do
      [[true]] ->
        context

      [[false]] ->
        raise "Expected task #{task_id} to be completed, but it is not"

      [] ->
        raise "Task #{task_id} does not exist in database"

      _ ->
        raise "Unexpected result when querying task #{task_id}"
    end
  end

  step "the task with id {int} should not be completed",
       %{args: [task_id]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT completed FROM tasks WHERE id = $1",
        [task_id]
      )

    case result.rows do
      [[false]] ->
        context

      [[true]] ->
        raise "Expected task #{task_id} to not be completed, but it is"

      [] ->
        raise "Task #{task_id} does not exist in database"

      _ ->
        raise "Unexpected result when querying task #{task_id}"
    end
  end

  step "the task with id {int} should have position {int}",
       %{args: [task_id, expected_position]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT position FROM tasks WHERE id = $1",
        [task_id]
      )

    case result.rows do
      [[position]] ->
        if position == expected_position do
          context
        else
          raise "Expected task #{task_id} to have position #{expected_position}, got #{position}"
        end

      [] ->
        raise "Task #{task_id} does not exist in database"

      _ ->
        raise "Unexpected result when querying task #{task_id}"
    end
  end

  step "the task with id {int} should not exist in the database",
       %{args: [task_id]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT id FROM tasks WHERE id = $1",
        [task_id]
      )

    case result.rows do
      [] ->
        context

      _ ->
        raise "Expected task #{task_id} to not exist, but it does"
    end
  end

  step "the task with id {int} should have tag with id {int}",
       %{args: [task_id, tag_id]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT tag_id FROM task_tags WHERE task_id = $1 AND tag_id = $2",
        [task_id, tag_id]
      )

    case result.rows do
      [[^tag_id]] ->
        context

      [] ->
        raise "Expected task #{task_id} to have tag #{tag_id}, but it does not"

      _ ->
        raise "Unexpected result when querying task-tag relationship"
    end
  end

  step "the task with id {int} should not have tag with id {int}",
       %{args: [task_id, tag_id]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT tag_id FROM task_tags WHERE task_id = $1 AND tag_id = $2",
        [task_id, tag_id]
      )

    case result.rows do
      [] ->
        context

      _ ->
        raise "Expected task #{task_id} to not have tag #{tag_id}, but it does"
    end
  end

  step "there should be {int} tasks in the database",
       %{args: [expected_count]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT COUNT(*) FROM tasks",
        []
      )

    case result.rows do
      [[count]] ->
        if count == expected_count do
          context
        else
          raise "Expected #{expected_count} tasks in database, got #{count}"
        end

      _ ->
        raise "Unexpected result when counting tasks"
    end
  end

  step "there should be {int} tags in the database",
       %{args: [expected_count]} = context do
    conn = TestDB.get_connection()

    result =
      Postgrex.query!(
        conn,
        "SELECT COUNT(*) FROM tags",
        []
      )

    case result.rows do
      [[count]] ->
        if count == expected_count do
          context
        else
          raise "Expected #{expected_count} tags in database, got #{count}"
        end

      _ ->
        raise "Unexpected result when counting tags"
    end
  end
end
