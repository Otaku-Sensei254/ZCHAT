defmodule VibeflowWeb.Admin.VerificationsLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts

  @impl true
  def mount(_params, _session, socket) do
    filter = "pending"

    {:ok,
     socket
     |> assign(:page_title, "Verification Requests")
     |> assign(:filter, filter)
     |> assign(:requests, load_requests(filter))}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter, requests: load_requests(filter))}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    request = Accounts.get_verification_request!(String.to_integer(id))

    case Accounts.approve_verification_request(request, socket.assigns.current_user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:requests, load_requests(socket.assigns.filter))
         |> put_flash(:info, "Verification approved")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not approve request")}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id, "admin_notes" => admin_notes}, socket) do
    request = Accounts.get_verification_request!(String.to_integer(id))
    admin_notes = normalize_notes(admin_notes)

    case Accounts.reject_verification_request(request, socket.assigns.current_user.id, admin_notes) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:requests, load_requests(socket.assigns.filter))
         |> put_flash(:info, "Verification rejected")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not reject request")}
    end
  end

  defp load_requests("pending"), do: Accounts.list_pending_verification_requests()
  defp load_requests(_), do: Accounts.list_verification_requests()

  defp normalize_notes(notes) do
    notes = String.trim(notes || "")
    if notes == "", do: nil, else: notes
  end
end
