const welcomeScreen = document.getElementById("welcomeScreen");
const chatScreen = document.getElementById("chatScreen");
const nameInput = document.getElementById("nameInput");
const joinButton = document.getElementById("joinButton");
const messagesDiv = document.getElementById("messages");
const messageInput = document.getElementById("messageInput");
const sendButton = document.getElementById("sendButton");
const statusDiv = document.getElementById("status");
const leaveButton = document.getElementById("leaveButton");

let ws = null;
let currentUser = "";

function showWelcomeScreen() {
  welcomeScreen.style.display = "flex";
  chatScreen.style.display = "none";
  nameInput.value = "";
  nameInput.focus();
}

function showChatScreen() {
  welcomeScreen.style.display = "none";
  chatScreen.style.display = "flex";
  messageInput.focus();
}

function disconnect() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.close();
  }
}

function joinChat() {
  const name = nameInput.value.trim();

  if (!name) {
    alert("Please enter your name");
    return;
  }

  currentUser = name;
  connect();
}

function leaveChat() {
  disconnect();
  showWelcomeScreen();
}

function connect() {
  disconnect();

  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const wsUrl = `${protocol}//${
    window.location.host
  }/chat?user=${encodeURIComponent(currentUser)}`;

  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    statusDiv.textContent = `Connected as ${currentUser}`;
    messageInput.disabled = false;
    sendButton.disabled = false;
    showChatScreen();
  };

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    if (data.type === "joined") {
      addSystemMessage(`${data.user} joined the chat`);
    } else if (data.type === "left") {
      addSystemMessage(`${data.user} left the chat`);
    } else if (data.type === "message") {
      addMessage(data.user, data.text, data.user === currentUser);
    }
  };

  ws.onclose = () => {
    statusDiv.textContent = "Disconnected";
    messageInput.disabled = true;
    sendButton.disabled = true;
    showWelcomeScreen();
  };

  ws.onerror = () => {
    addSystemMessage("Connection error");
  };
}

function addMessage(user, text, isCurrentUser) {
  const messageDiv = document.createElement("div");
  messageDiv.className = `message ${
    isCurrentUser ? "user-message" : "other-message"
  }`;

  const userDiv = document.createElement("div");
  userDiv.className = "user";
  userDiv.textContent = user;

  const textDiv = document.createElement("div");
  textDiv.className = "text";
  textDiv.textContent = text;

  messageDiv.appendChild(userDiv);
  messageDiv.appendChild(textDiv);
  messagesDiv.appendChild(messageDiv);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function addSystemMessage(text) {
  const messageDiv = document.createElement("div");
  messageDiv.className = "message system-message";
  messageDiv.textContent = text;
  messagesDiv.appendChild(messageDiv);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function sendMessage() {
  const message = messageInput.value.trim();
  if (message && ws && ws.readyState === WebSocket.OPEN) {
    ws.send(message);
    messageInput.value = "";
  }
}

joinButton.addEventListener("click", joinChat);
sendButton.addEventListener("click", sendMessage);
leaveButton.addEventListener("click", leaveChat);

messageInput.addEventListener("keypress", (e) => {
  if (e.key === "Enter") {
    sendMessage();
  }
});

nameInput.addEventListener("keypress", (e) => {
  if (e.key === "Enter") {
    joinChat();
  }
});

// Show welcome screen on load
showWelcomeScreen();
