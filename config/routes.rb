Specbook::Engine.routes.draw do
  root to: "viewer#show"
  get "screenshots/:filename", to: "viewer#screenshot", as: :screenshot, constraints: { filename: /[^\/]+/ }
  get "traces/:filename", to: "viewer#trace", as: :trace, constraints: { filename: /[^\/]+/ }
  post "traces/:filename/view", to: "viewer#view_trace", as: :view_trace, constraints: { filename: /[^\/]+/ }
end
