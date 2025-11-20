defmodule TestDB do
  @moduledoc """
  Shared database connection pool for integration tests.
  Uses a single connection pool across all test steps to avoid exhausting database connections.
  """

  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_connection do
    GenServer.call(__MODULE__, :get_connection, 30_000)
  end

  @impl true
  def init(:ok) do
    # Parse DATABASE_URL
    database_url =
      System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost:5437/tasks_db"

    uri = URI.parse(database_url)

    db_config = [
      hostname: uri.host || "localhost",
      port: uri.port || 5437,
      database: String.trim_leading(uri.path || "/tasks_db", "/"),
      username: (uri.userinfo && String.split(uri.userinfo, ":") |> List.first()) || "postgres",
      password: (uri.userinfo && String.split(uri.userinfo, ":") |> List.last()) || "postgres",
      pool_size: 1
    ]

    case Postgrex.start_link(db_config) do
      {:ok, conn} ->
        IO.puts("✓ Test database connection pool started: #{db_config[:database]}")
        {:ok, %{connection: conn}}

      {:error, reason} ->
        IO.puts("✗ Failed to start test database connection: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_connection, _from, state) do
    {:reply, state.connection, state}
  end

  @doc """
  Clear all test tables using DELETE instead of TRUNCATE.
  Auto-discovers all tables in public schema except migrations.
  Runs before each test to ensure isolation.
  """
  def clear_all_tables do
    conn = get_connection()

    # Use advisory lock to serialize cleanup across all connections
    Postgrex.query!(conn, "SELECT pg_advisory_lock(123456789)", [])

    try do
      Postgrex.query!(
        conn,
        """
          DO $$
          DECLARE
              r RECORD;
          BEGIN
              -- Disable triggers on all tables for performance
              FOR r IN
                SELECT tablename
                FROM pg_tables
                WHERE schemaname = 'public'
                  AND tablename != '_migrations'
                ORDER BY tablename
              LOOP
                  EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' DISABLE TRIGGER ALL';
              END LOOP;

              -- Delete all rows from all tables
              FOR r IN
                SELECT tablename
                FROM pg_tables
                WHERE schemaname = 'public'
                  AND tablename != '_migrations'
                ORDER BY tablename
              LOOP
                  EXECUTE 'DELETE FROM ' || quote_ident(r.tablename);
              END LOOP;

              -- Re-enable triggers
              FOR r IN
                SELECT tablename
                FROM pg_tables
                WHERE schemaname = 'public'
                  AND tablename != '_migrations'
                ORDER BY tablename
              LOOP
                  EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' ENABLE TRIGGER ALL';
              END LOOP;

              -- Reset all sequences to 1
              FOR r IN
                SELECT c.relname
                FROM pg_class c
                WHERE c.relkind = 'S'
                  AND c.relnamespace = 'public'::regnamespace
              LOOP
                  EXECUTE 'ALTER SEQUENCE ' || quote_ident(r.relname) || ' RESTART WITH 1';
              END LOOP;
          END $$;
        """,
        []
      )

      :ok
    after
      # Always release the advisory lock
      Postgrex.query!(conn, "SELECT pg_advisory_unlock(123456789)", [])
    end
  end
end
