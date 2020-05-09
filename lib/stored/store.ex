defmodule Stored.Store do
  @type record :: Stored.Backend.record()

  @callback backend_created() :: no_return
  @callback after_backend_create() :: no_return
  @callback after_put(record) :: no_return
  @callback after_clear() :: no_return
  @optional_callbacks after_backend_create: 0, backend_created: 0, after_put: 1, after_clear: 0

  defmacro __using__(_) do
    quote location: :keep do
      use GenServer

      @behaviour Stored.Store

      @type store_id :: atom
      @type record :: Stored.Backend.record()
      @type key :: Stored.Backend.key()

      @default_id :default
      @default_backend Stored.Backends.ETS

      defmodule State do
        @type t :: %State{id: atom, name: atom, backend: module}
        defstruct ~w(id name backend)a
      end

      def start_link(args) do
        id = Keyword.get(args, :id, @default_id)
        backend = Keyword.get(args, :backend, @default_backend)
        name = process_name(id)
        state = %State{id: id, name: name, backend: backend}

        GenServer.start_link(__MODULE__, state, name: name)
      end

      @spec process_name(store_id) :: atom
      def process_name(store_id), do: :"#{__MODULE__}_#{store_id}"

      @since "0.0.6"
      @deprecated "Use Stored.Store.process_name/1 instead"
      @spec to_name(store_id) :: atom
      def to_name(store_id), do: process_name(store_id)

      @spec put(record) :: {:ok, {key, record}}
      def put(record, store_id \\ @default_id) do
        store_id
        |> process_name
        |> GenServer.call({:put, record})
      end

      @spec find(key) :: {:ok, record} | {:error, :not_found}
      def find(key, store_id \\ @default_id) do
        store_id
        |> process_name
        |> GenServer.call({:find, key})
      end

      @spec all :: [record]
      def all(store_id \\ @default_id) do
        store_id
        |> process_name
        |> GenServer.call(:all)
      end

      @spec clear :: :ok
      def clear(store_id \\ @default_id) do
        store_id
        |> process_name
        |> GenServer.call(:clear)
      end

      def init(state), do: {:ok, state, {:continue, :init}}

      def handle_continue(:init, state) do
        :ok = state.backend.create(state.name)
        after_backend_create()
        backend_created()
        {:noreply, state}
      end

      def handle_call({:put, record}, _from, state) do
        response = state.backend.put(record, state.name)
        after_put(record)
        {:reply, response, state}
      end

      def handle_call({:find, key}, _from, state) do
        response = state.backend.find(key, state.name)
        {:reply, response, state}
      end

      def handle_call(:all, _from, state) do
        response = state.backend.all(state.name)
        {:reply, response, state}
      end

      def handle_call(:clear, _from, state) do
        response = state.backend.clear(state.name)
        after_clear()
        {:reply, response, state}
      end

      def backend_created, do: nil
      def after_backend_create, do: nil
      def after_put(record), do: nil
      def after_clear, do: nil

      defoverridable after_backend_create: 0, backend_created: 0, after_put: 1, after_clear: 0
    end
  end
end
