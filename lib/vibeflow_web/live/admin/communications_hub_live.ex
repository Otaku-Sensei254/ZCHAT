defmodule VibeflowWeb.Admin.CommunicationsHubLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts

  @impl true
  def mount(_params, _session, socket) do
    if !Accounts.user_has_role?(socket.assigns.current_user, "admin") do
      {:ok, socket |> put_flash(:error, "Unauthorized") |> redirect(to: "/")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Communications Hub")
       |> assign(:subject, "")
       |> assign(:body, "")
       |> assign(:sender_name, "VibeFlow Team")
       |> assign(:preview_visible, false)
       |> assign(:email_count, nil)
       |> assign(:sending, false)}
    end
  end

  # Handle form input changes
  @impl true
  def handle_event("change", %{"subject" => subject}, socket) do
    {:noreply, assign(socket, :subject, subject)}
  end

  def handle_event("change", %{"body" => body}, socket) do
    {:noreply, assign(socket, :body, body)}
  end

  def handle_event("change", %{"sender_name" => sender_name}, socket) do
    {:noreply, assign(socket, :sender_name, sender_name)}
  end

  def handle_event("change", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("preview", _params, socket) do
    {:noreply, assign(socket, :preview_visible, true)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :preview_visible, false)}
  end

  @impl true
  def handle_event("send", _params, socket) do
    subject = socket.assigns.subject
    body = socket.assigns.body
    sender = socket.assigns.sender_name

    if String.trim(subject) == "" or String.trim(body) == "" do
      {:noreply,
       socket
       |> put_flash(:error, "Subject and message body are required.")}
    else
      socket = assign(socket, :sending, true)

      Task.Supervisor.start_child(
        Vibeflow.TaskSupervisor,
        fn ->
          result = Accounts.broadcast_email(subject, body, sender)
          send(self(), {:email_sent, result})
        end,
        restart: false
      )

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:email_sent, {:ok, sent_count, total_count}}, socket) do
    {:noreply,
     socket
     |> assign(:sending, false)
     |> assign(:email_count, {sent_count, total_count})
     |> put_flash(:info, "Email broadcast completed! Sent to #{sent_count}/#{total_count} users.")
     |> assign(:subject, "")
     |> assign(:body, "")}
  end

  @impl true
  def handle_info({:email_sent, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:sending, false)
     |> put_flash(:error, "Failed to send emails: #{inspect(reason)}")}
  end
end
