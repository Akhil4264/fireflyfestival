
defmodule Firefly do
  use Agent
  def start_state_map(n) do
    Agent.start_link(fn -> Enum.reduce(1..n, %{}, fn i, acc -> Map.put(acc, "task_#{i}", false) end) end, name: __MODULE__)
  end

  def get_state_map do
    Agent.get(__MODULE__, & &1)
  end

  def get_state(id) do
    Agent.get(__MODULE__, fn state_map -> Map.get(state_map, id) end)
  end

  def update_state(id, value) do
    Agent.update(__MODULE__, fn state_map -> Map.put(state_map, id, value) end)
    IO.puts("State updated for #{id}: #{value}")
  end

  def print_state(state) do
    case state do
      true -> IO.write("B")
      false -> IO.write(" ")
    end
  end

  def print_states(n) do
    IO.puts("\e[2J\e[H")
    Enum.each(1..n, fn i ->
      print_state(get_state("task_#{i}")) end)
  end

  def start_n_tasks(n,off_time \\ 2000,print_time \\ 30) do
    start_state_map(n)
    Enum.each(1..n, fn i ->
    Task.Supervisor.start_child(Firefly.TaskSupervisor, fn ->
      name = :"task_#{i}"
      Process.register(self(), name)
      rand_time = :rand.uniform(off_time)
      # rand_time = (div(off_time - 500,n)) * i
      loop(n,i, false, off_time - rand_time)
    end)
    end)
    # _ref = :timer.apply_interval(print_time, Firefly, :print_states, [n] )
    listen()
  end

  def listen() do
    receive do
      {:signal,from_name} ->
        listen()
    end
  end

  def broadcast_signal(n,name) do
    Enum.map(1..n,fn i -> String.to_atom("task_#{i}") end)
      |> Enum.each(fn r_name ->
        pid = Process.whereis(r_name)
        if Process.alive?(pid) and r_name != name do
          send(pid, {:signal, name})
        end
      end)
  end

  defp loop(n,id,state,duration,off_time \\ 2000,on_time \\ 500,diff_time \\ 500,flick_time \\ 100) do
    IO.puts("Task #{id} started with state: #{state} and duration: #{duration} ms")
    {:registered_name, p_name} = Process.info(self(), :registered_name)
    name_string = Atom.to_string(p_name)
    last_flick = flick_time >= duration
    start_time = :erlang.monotonic_time(:millisecond)
    if(state) do
      receive do
        {:signal,from_name} ->
          end_time = :erlang.monotonic_time(:millisecond)
          IO.puts("Task #{id} received signal from #{from_name}, remaining duration: #{duration - (end_time - start_time)} ms")
          loop(n,id,state,duration - (end_time - start_time))
      after flick_time ->
        if(last_flick) do
          update_state(name_string, false)
          loop(n,id,false,off_time)
        else
          # end_time = :erlang.monotonic_time(:millisecond)
          # loop(n,id,state,duration - flick_time - (end_time - start_time))
          loop(n,id,state,duration - flick_time)
        end
      end
    else
      receive do
        {:signal,from_name} ->
          end_time = :erlang.monotonic_time(:millisecond)
          if duration-(end_time-start_time) <= diff_time do
            update_state(name_string, true)
            broadcast_signal(n,p_name)
            loop(n,id,true,on_time)
          else
            IO.puts("Task #{id} received signal from #{from_name}, remaining duration: #{duration - (end_time - start_time)-diff_time} ms")
            loop(n,id,state,duration-(end_time-start_time)-diff_time)
          end
      # after
      #   duration ->
      #     update_state(name_string, true)
      #     broadcast_signal(n,p_name)
      #     loop(n,id,true,on_time)
      after flick_time ->
        if(last_flick) do
          update_state(name_string, true)
          broadcast_signal(n,p_name)
          loop(n,id,true,on_time)
        else
          # end_time = :erlang.monotonic_time(:millisecond)
          # loop(n,id,state,duration - flick_time - (end_time - start_time))
          loop(n,id,state,duration - flick_time)
        end
      end
    end
  end


end

Task.Supervisor.start_link(name: Firefly.TaskSupervisor)
Firefly.start_n_tasks 3
