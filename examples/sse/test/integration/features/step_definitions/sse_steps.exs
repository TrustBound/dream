defmodule SseSteps do
  use Cucumber.StepDefinition

  @base_url "http://localhost:8081"

  step "I connect to SSE at {string}", %{args: [path]} = context do
    url = "#{@base_url}#{path}"

    {:ok, %HTTPoison.AsyncResponse{id: ref}} =
      HTTPoison.get(url, [{"Accept", "text/event-stream"}],
        stream_to: self(),
        recv_timeout: 15_000
      )

    # Wait for status
    receive do
      %HTTPoison.AsyncStatus{id: ^ref, code: 200} -> :ok
    after
      5000 -> raise "Timeout waiting for SSE response status"
    end

    # Wait for headers
    receive do
      %HTTPoison.AsyncHeaders{id: ^ref} -> :ok
    after
      5000 -> raise "Timeout waiting for SSE response headers"
    end

    context
    |> Map.put(:sse_ref, ref)
    |> Map.put(:sse_events, [])
  end

  step "I should receive at least {int} SSE events within {int} seconds",
       %{args: [min_count, timeout_secs]} = context do
    events = collect_events(context.sse_ref, min_count, timeout_secs * 1000)

    if length(events) >= min_count do
      Map.put(context, :sse_events, events)
    else
      raise "Expected at least #{min_count} events, got #{length(events)}"
    end
  end

  step "each event should have a {string} field", %{args: [field_name]} = context do
    Enum.each(context.sse_events, fn event ->
      unless Map.has_key?(event, field_name) do
        raise "Event missing '#{field_name}' field: #{inspect(event)}"
      end
    end)

    context
  end

  step "I should receive an SSE event with name {string}", %{args: [expected_name]} = context do
    events = collect_events(context.sse_ref, 3, 5000)

    matching =
      Enum.find(events, fn event ->
        Map.get(event, "event") == expected_name
      end)

    case matching do
      nil -> raise "No event with name '#{expected_name}' found in #{inspect(events)}"
      event -> Map.put(context, :sse_events, [event | Map.get(context, :sse_events, [])])
    end
  end

  step "the event should have an {string} field", %{args: [field_name]} = context do
    [latest | _] = context.sse_events

    unless Map.has_key?(latest, field_name) do
      raise "Event missing '#{field_name}' field: #{inspect(latest)}"
    end

    context
  end

  step "I wait for {int} events", %{args: [count]} = context do
    Map.put(context, :expected_event_count, count)
  end

  step "all {int} events should arrive within {int} seconds",
       %{args: [count, timeout_secs]} = context do
    events = collect_events(context.sse_ref, count, timeout_secs * 1000)

    if length(events) >= count do
      context
    else
      raise "Expected #{count} events within #{timeout_secs}s, got #{length(events)}"
    end
  end

  defp collect_events(ref, count, timeout_ms) do
    collect_events_acc(ref, count, timeout_ms, [], "")
  end

  defp collect_events_acc(_ref, count, _timeout_ms, events, _buffer) when length(events) >= count do
    Enum.reverse(events)
  end

  defp collect_events_acc(ref, count, timeout_ms, events, buffer) do
    receive do
      %HTTPoison.AsyncChunk{id: ^ref, chunk: chunk} ->
        new_buffer = buffer <> chunk
        {new_events, remaining} = parse_sse_buffer(new_buffer)
        all_events = events ++ new_events
        collect_events_acc(ref, count, timeout_ms, all_events, remaining)

      %HTTPoison.AsyncEnd{id: ^ref} ->
        Enum.reverse(events)
    after
      timeout_ms ->
        Enum.reverse(events)
    end
  end

  defp parse_sse_buffer(buffer) do
    parts = String.split(buffer, "\n\n")

    case parts do
      [only] ->
        {[], only}

      parts ->
        {complete, [remaining]} = Enum.split(parts, -1)

        events =
          complete
          |> Enum.filter(&(&1 != ""))
          |> Enum.map(&parse_sse_event/1)

        {events, remaining}
    end
  end

  defp parse_sse_event(raw) do
    raw
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        [key, value] -> Map.put(acc, key, value)
        [key] -> Map.put(acc, key, "")
        _ -> acc
      end
    end)
  end
end
