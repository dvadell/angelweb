defmodule AngelWeb.IndexLive.FormComponent do
  use AngelWeb, :live_component

  alias Angel.Graphs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage index records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="index-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:short_name]} type="text" label="Short name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Index</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{index: index} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Graphs.change_index(index))
     end)}
  end

  @impl true
  def handle_event("validate", %{"index" => index_params}, socket) do
    changeset = Graphs.change_index(socket.assigns.index, index_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"index" => index_params}, socket) do
    save_index(socket, socket.assigns.action, index_params)
  end

  defp save_index(socket, :edit, index_params) do
    case Graphs.update_index(socket.assigns.index, index_params) do
      {:ok, index} ->
        notify_parent({:saved, index})

        {:noreply,
         socket
         |> put_flash(:info, "Index updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_index(socket, :new, index_params) do
    case Graphs.create_index(index_params) do
      {:ok, index} ->
        notify_parent({:saved, index})

        {:noreply,
         socket
         |> put_flash(:info, "Index created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
