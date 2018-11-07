{application,kv_server,
             [{applications,[kernel,stdlib,elixir,logger]},
              {description,"kv_server"},
              {modules,['Elixir.KVServer','Elixir.KVServer.Application',
                        'Elixir.KVServer.Room','Elixir.KVServer.User']},
              {registered,[]},
              {vsn,"0.1.0"},
              {mod,{'Elixir.KVServer.Application',[]}}]}.
