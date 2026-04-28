Rails.application.routes.draw do
  mount Specbook::Engine => "/specs"
  root to: proc { [200, {}, ["dummy"]] }
end
