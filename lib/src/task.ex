defmodule FireFly.Source.Task do
  def task do
    :timer.apply_interval(100, IO, :puts, ["hello"])
  end
end
