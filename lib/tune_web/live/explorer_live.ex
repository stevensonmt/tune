defmodule TuneWeb.ExplorerLive do
  use TuneWeb, :live_view

  alias TuneWeb.{PlayerView, TrackView}

  @initial_state [
    status: :not_authenticated,
    q: nil,
    tracks: [],
    user: nil,
    now_playing: :not_playing
  ]

  @impl true
  def mount(_params, session, socket) do
    with {:ok, session_id} <- Map.fetch(session, "spotify_id"),
         {:ok, credentials} <- Map.fetch(session, "spotify_credentials") do
      {:ok, load_user(session_id, credentials, socket)}
    else
      :error ->
        {:ok, assign(socket, @initial_state)}
    end
  end

  @impl true
  def handle_params(%{"q" => q}, _url, socket) do
    if String.length(q) >= 3 do
      socket = assign(socket, :q, q)
      types = [:track]

      case spotify().search(socket.assigns.session_id, q, types) do
        {:ok, results} ->
          {:noreply, assign(socket, :tracks, results.tracks)}

        _error ->
          {:noreply, socket}
      end
    else
      {:noreply,
       socket
       |> assign(:q, nil)
       |> assign(:tracks, [])}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:q, nil)
     |> assign(:tracks, [])}
  end

  @impl true
  def handle_event("toggle_play_pause", %{"key" => " "}, socket) do
    spotify().toggle_play(socket.assigns.session_id)

    {:noreply, socket}
  end

  def handle_event("toggle_play_pause", %{"key" => _}, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_play_pause", _params, socket) do
    spotify().toggle_play(socket.assigns.session_id)

    {:noreply, socket}
  end

  def handle_event("search", %{"q" => ""}, socket) do
    {:noreply, push_patch(socket, to: Routes.explorer_path(socket, :index))}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: Routes.explorer_path(socket, :index, %{q: q}))}
  end

  defp spotify, do: Application.get_env(:tune, :spotify)

  defp load_user(session_id, credentials, socket) do
    with :ok <- spotify().setup(session_id, credentials),
         %Tune.Spotify.Schema.User{} = user = spotify().get_profile(session_id),
         now_playing = spotify().now_playing(session_id) do
      if connected?(socket) do
        Tune.Spotify.Session.subscribe(session_id)
      end

      socket
      |> assign(@initial_state)
      |> assign(
        status: :authenticated,
        session_id: session_id,
        user: user,
        now_playing: now_playing
      )
    else
      {:error, _reason} ->
        redirect(socket, to: "/auth/logout")
    end
  end

  @impl true
  def handle_info(now_playing, socket) do
    {:noreply, assign(socket, :now_playing, now_playing)}
  end
end
