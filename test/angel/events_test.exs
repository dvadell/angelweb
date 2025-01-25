defmodule Angel.EventsTest do
  use Angel.DataCase

  alias Angel.Events

  describe "events" do
    alias Angel.Events.Event

    import Angel.EventsFixtures

    @invalid_attrs %{text: nil, for_graph: nil}

    test "list_events/0 returns all events" do
      event = event_fixture()
      assert Events.list_events() == [event]
    end

    test "get_event!/1 returns the event with given id" do
      event = event_fixture()
      assert Events.get_event!(event.id) == event
    end

    test "create_event/1 with valid data creates a event" do
      valid_attrs = %{text: "some text", for_graph: "some for_graph"}

      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs)
      assert event.text == "some text"
      assert event.for_graph == "some for_graph"
    end

    test "create_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(@invalid_attrs)
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()
      update_attrs = %{text: "some updated text", for_graph: "some updated for_graph"}

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.text == "some updated text"
      assert event.for_graph == "some updated for_graph"
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, @invalid_attrs)
      assert event == Events.get_event!(event.id)
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end
end
