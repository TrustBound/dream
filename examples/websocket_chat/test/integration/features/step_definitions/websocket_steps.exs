defmodule WebsocketSteps do
  use Cucumber.StepDefinition

  alias WebSockex

  @base_url "ws://localhost:8080"

  defmodule TestClient do
    use WebSockex

    def start_link(url, test_pid) do
      WebSockex.start_link(url, __MODULE__, %{test_pid: test_pid, messages: []})
    end

    def send_message(pid, message) do
      WebSockex.send_frame(pid, {:text, message})
    end

    def get_messages(pid) do
      WebSockex.cast(pid, :get_messages)
    end

    @impl true
    def handle_frame({:text, message}, state) do
      decoded = Jason.decode!(message)
      send(state.test_pid, {:ws_message, decoded})
      {:ok, %{state | messages: [decoded | state.messages]}}
    end

    @impl true
    def handle_frame(_frame, state), do: {:ok, state}

    @impl true
    def handle_cast(:get_messages, state) do
      send(state.test_pid, {:messages, Enum.reverse(state.messages)})
      {:ok, state}
    end

    @impl true
    def handle_cast(:close, state) do
      {:close, state}
    end

    @impl true
    def handle_disconnect(_reason, state), do: {:ok, state}
  end

  step "I upgrade to WebSocket at {string}", %{args: [path]} = context do
    url = "#{@base_url}#{path}"
    {:ok, pid} = TestClient.start_link(url, self())
    Map.put(context, :ws_conn, pid)
  end

  step "I connect to WebSocket at {string}", %{args: [path]} = context do
    url = "#{@base_url}#{path}"
    {:ok, pid} = TestClient.start_link(url, self())
    
    # Wait for and consume join message
    receive do
      {:ws_message, %{"type" => "joined"}} -> :ok
    after
      2000 -> raise "Timeout waiting for join confirmation"
    end
    
    Map.put(context, :ws_conn, pid)
  end

  step "the WebSocket connection should be established", %{} = context do
    # Connection establishment is verified by successful start_link
    context
  end

  step "I should receive a {string} message for {string}",
       %{args: [message_type, user]} = context do
    receive do
      {:ws_message, %{"type" => ^message_type, "user" => ^user}} ->
        context

      {:ws_message, msg} ->
        raise "Expected #{message_type} for #{user}, got: #{inspect(msg)}"
    after
      2000 -> raise "Timeout waiting for #{message_type} message for #{user}"
    end
  end

  step "I send WebSocket text {string}", %{args: [text]} = context do
    TestClient.send_message(context.ws_conn, text)
    context
  end

  step "I should receive a {string} from {string} with text {string}",
       %{args: [message_type, user, text]} = context do
    receive do
      {:ws_message, %{"type" => ^message_type, "user" => ^user, "text" => ^text}} ->
        context

      {:ws_message, msg} ->
        raise "Expected #{message_type} from #{user} with text '#{text}', got: #{inspect(msg)}"
    after
      2000 -> raise "Timeout waiting for message"
    end
  end

  step "user {string} connects to the chat", %{args: [username]} = context do
    url = "#{@base_url}/chat?user=#{URI.encode(username)}"
    {:ok, pid} = TestClient.start_link(url, self())
    
    # Wait for this user's join message only
    receive do
      {:ws_message, %{"type" => "joined", "user" => ^username}} -> :ok
    after
      2000 -> raise "Timeout waiting for #{username} join confirmation"
    end

    users = Map.get(context, :users, %{})
    Map.put(context, :users, Map.put(users, username, pid))
  end

  step "user {string} sends message {string}", %{args: [username, message]} = context do
    pid = context.users[username]
    TestClient.send_message(pid, message)
    context
  end

  step "user {string} should receive message from {string} saying {string}",
       %{args: [_receiver, sender, text]} = context do
    # Messages are broadcast, so we need to check the test process mailbox
    # Skip any other messages and find the one we're looking for
    wait_for_message(sender, text, 2000)
    context
  end
  
  defp wait_for_message(sender, text, timeout) do
    receive do
      {:ws_message, %{"type" => "message", "user" => ^sender, "text" => ^text}} ->
        :ok

      {:ws_message, _msg} ->
        # Skip this message and keep waiting
        wait_for_message(sender, text, timeout - 50)

      other ->
        IO.puts("Unexpected message: #{inspect(other)}")
        wait_for_message(sender, text, timeout - 50)
    after
      timeout -> raise "Timeout waiting for message from #{sender} with text '#{text}'"
    end
  end

  step "user {string} should receive {string} notification for {string}",
       %{args: [_receiver, notification_type, username]} = context do
    wait_for_notification(notification_type, username, 2000)
    context
  end
  
  defp wait_for_notification(notification_type, username, timeout) do
    receive do
      {:ws_message, %{"type" => ^notification_type, "user" => ^username}} ->
        :ok

      {:ws_message, _msg} ->
        # Skip this message and keep waiting
        wait_for_notification(notification_type, username, timeout - 50)
    after
      timeout -> raise "Timeout waiting for #{notification_type} notification for #{username}"
    end
  end

  step "user {string} disconnects", %{args: [username]} = context do
    pid = context.users[username]
    WebSockex.cast(pid, :close)
    Process.sleep(100)
    context
  end
end

