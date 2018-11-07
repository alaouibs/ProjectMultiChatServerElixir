defmodule KVServer do
  require Logger
  # Create a Room structure that has a list of clients
  defmodule Room do
    defstruct users: []
  end

  defmodule User do
    defstruct name: "", socket: Socket
  end

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    {:ok, agent} = Agent.start_link fn -> [] end
    IO.puts "Creating a new room"
    Agent.update(agent, fn room -> %Room{} end)
    IO.puts "Accepting connections on port #{port}"
    loop_acceptor(socket, agent)
  end

defp loop_acceptor(socket, agent) do
    {:ok, client} = :gen_tcp.accept(socket)
    # Notice to the user
    write_line(client, "Nickname : /join <name>\n")
    Task.Supervisor.start_child(KVServer.TaskSupervisor, fn -> serve(client, agent) end)

    loop_acceptor(socket, agent)
end
  defp serve(socket, agent) do
    case read_line(socket) do
      {:ok, socket, :join, nick} ->
        write_line(socket, "welcome on board #{nick}\n")
        join_room(socket, agent, nick)
        serve(socket, agent)
      {:ok, socket, :leave} ->
        leave_room(socket, agent)
        serve(socket, agent)
      {:ok, socket, :say, message} ->
        say(socket, agent, message)
        serve(socket, agent)
      {:error, cause} -> IO.puts "Exited: #{cause}"
      _ -> IO.puts "Exited: Something bad happened"
    end
  end

  defp read_line(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} -> 
        data = String.strip(data)
        data_list = String.split(data)
        command = hd(data_list)
        IO.puts "data: #{data}\ncommand: #{command}"
        case command do
          "/join" -> {:ok, socket, :join, tl(data_list)}
          "/leave" -> {:ok, socket, :leave}
          _ -> {:ok, socket, :say, data}
        end

      {:error, _} -> {:error, "Socket Closed"}
      _ -> {:error, "No clue..."}
    end
  end

  defp write_line(line, socket) do
    :gen_tcp.send(line, socket)
  end


  # Gets the room from the agent
  defp get_room(agent) do
    Agent.get(agent, fn room -> room end)
  end

  # Sets the room stored in the agent
  defp set_room(agent, new_room) do
   Agent.update(agent, fn room -> new_room end)
  end

  # Finds a user by socket
  defp find_user(users, socket) do
    Enum.find(users, fn(user) -> user.socket == socket end)
  end

  # Replace a user
  defp replace_user(users, user) do
    index = Enum.find_index(users, fn(u) -> u.socket == user.socket end)
    List.replace_at(users, index, user)
  end

  # Adds the client to the room list
  defp join_room(client, agent, nick \\ "Anonymous") do
    room = get_room(agent)
    user = %User{name: to_string(nick), socket: client}
    new_room = %{room | users: room.users ++ [user]}
    IO.puts "User #{nick} joined\n"
    notify_all(new_room, client, "User #{nick} joined\n")
    set_room(agent, new_room)
  end

  # Removes the client from the room list
  defp leave_room(client, agent) do
    room = get_room(agent)
    user = find_user(room.users, client)
    new_room = %{room | users: room.users -- [user]}
    IO.puts "User #{user.name} left"
    notify_all(new_room, client, "User #{user.name} left")
    set_room(agent, new_room)
  end


  # Notifies clients of the users message
  defp say(client_socket, agent, message) do
    room = get_room(agent)
    user = find_user(room.users, client_socket)
    notify_all(room, client_socket, "#{user.name}: #{message}\n")
  end

  # Send 'message' to all clients except 'sender'
    defp notify_all(room, sender, message) do
      Enum.each room.users, fn(client) ->
          if client.socket != sender do
            write_line(client.socket, message)
          end
      end
    end

end
