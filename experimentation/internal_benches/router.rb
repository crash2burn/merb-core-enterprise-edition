require File.join(File.dirname(__FILE__), "..", "..", "lib", "merb-core")

Merb::Router.prepare do |r|
  r.namespace :admin do |a|
    a.resources :users do |u|
      u.resources :comments
    end
  end
  
  r.resources :users do |u|
    u.resources :comments
  end
  
  r.match!("/:account/invitation/:token", :account => /^[a-zA-Z]{5,20}$/, :token => /^[\dA-F]{32}$/).name(:conditional)
  
  r.default_routes
end

require "rubygems"
require "rbench"

RBench.run(50_000) do
  report "resources" do
    Merb::Router.generate(:user, :id => 123)
  end
  
  report "nested resources" do
    Merb::Router.generate(:user_comment, :user_id => 123, :id => "456")
  end
  
  report "namespaced nested resource" do
    Merb::Router.generate(:admin_user_comment, :user_id => 123, :id => "456")
  end
  
  report "route with conditions" do
    Merb::Router.generate(:conditional, :account => "helloworld", :token => "0987654321ABCDEF0987654321ABCDEF")
  end
  
  report "default routes" do
    Merb::Router.generate(:default, :controller => "foo", :action => "bar", :id => 5, :format => :xml)
  end
end


__END__

                                   Results |
--------------------------------------------
resources                            1.866 |
nested resources                     2.454 |
namespaced nested resource           2.439 |
route with conditions                1.958 |
default routes                       4.006 |