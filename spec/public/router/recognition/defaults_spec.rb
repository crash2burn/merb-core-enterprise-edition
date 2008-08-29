require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "Recognizing requests for the routes with default values for variables" do
  
  it "should use the specified default value if the variable is not included in the path" do
    Merb::Router.prepare do |r|
      r.defaults(:controller => "foos", :action => "bars").match("/").to
    end
    
    route_to("/").should have_route(:controller => "foos", :action => "bars")
  end
  
  it "should use the specified default value if the variable is included in the path but wasn't matched" do
    Merb::Router.prepare do |r|
      r.defaults(:action => "index").match("/:controller(/:action)").to
    end
    
    route_to("/foos").should have_route(:controller => "foos", :action => "index")
  end
  
  it "should use the matched value for required variables" do
    Merb::Router.prepare do |r|
      r.defaults(:action => "index").match("/:controller/:action").to
    end
    
    route_to("/foos/bar").should have_route(:controller => "foos", :action => "bar")
  end
  
  it "should use the matched value for optional variables" do
    Merb::Router.prepare do |r|
      r.defaults(:action => "index").match("/:controller(/:action)").to
    end
    
    route_to("/foos/bar").should have_route(:controller => "foos", :action => "bar")
  end
  
  it "should use the params when there are some set" do
    Merb::Router.prepare do |r|
      r.match("/go").defaults(:foo => "bar").to(:foo => "baz")
    end
    
    route_to("/go").should have_route(:foo => "baz")
  end
  
  it "should be used in constructed params when the optional segment wasn't matched" do
    Merb::Router.prepare do |r|
      r.match("/go(/:foo)").defaults(:foo => "bar").to(:foo => "foo/:foo")
    end
    
    route_to("/go").should have_route(:foo => "foo/bar")
  end
  
  it "should combine multiple default params when nesting defaults" do
    Merb::Router.prepare do |r|
      r.defaults(:controller => "home") do |d|
        d.defaults(:action => "index").match("/(:controller/:action)").to
      end
    end
    
    route_to("/").should have_route(:controller => "home", :action => "index")
  end
  
  it "should overwrite previously set default params with the new ones when nesting" do
    Merb::Router.prepare do |r|
      r.defaults(:action => "index") do |d|
        d.defaults(:action => "notindex").match("/:account(/:action)").to
      end
    end
    
    route_to("/awesome").should have_route(:account => "awesome", :action => "notindex")
  end
  
  it "should preserve previously set conditions" do
    Merb::Router.prepare do |r|
      r.match("/blah") do |b|
        b.defaults(:foo => "bar").to(:controller => "baz")
      end
    end
    
    route_to("/blah").should have_route(:controller => "baz", :foo => "bar")
  end
  
  it "should be preserved through condition blocks" do
    Merb::Router.prepare do |r|
      r.defaults(:foo => "bar") do |f|
        f.match("/go").to
      end
    end
    
    route_to("/go").should have_route(:foo => "bar")
  end
  
  it "should preserve previously set params" do
    Merb::Router.prepare do |r|
      r.to(:controller => "bar") do |b|
        b.defaults(:action => "baz").match("/go").to
      end
    end
    
    route_to("/go").should have_route(:controller => "bar", :action => "baz")
  end
  
  it "should be preserved through params blocks" do
    Merb::Router.prepare do |r|
      r.defaults(:foo => "bar") do |f|
        f.match("/go").to(:controller => "gos")
      end
    end
    
    route_to("/go").should have_route(:controller => "gos", :foo => "bar")
  end
end