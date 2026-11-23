const source = new EventSource("/events");

// Listen for all events (default event type is "message")
source.onmessage = (event) => {
  console.log("data:", event.data);
};

// Listen for named events
source.addEventListener("tick", (event) => {
  console.log("tick:", event.data, "id:", event.lastEventId);
});

// Handle errors (browser reconnects automatically)
source.onerror = (event) => {
  console.log("SSE connection lost, reconnecting...");
};
