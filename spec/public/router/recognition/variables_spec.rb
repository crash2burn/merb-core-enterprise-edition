require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do
  
  describe "a route with variables in the path" do
    
    it "should create keys for each named variable" do
      Merb::Router.prepare do
        match("/:foo/:bar").register
      end
      
      route_to("/one/two").should have_route(:foo => "one", :bar => "two")
    end
    
    it "should be able to match :controller, :action, and :id from the route" do
      Merb::Router.prepare do
        match("/:controller/:action/:id").register
      end
      
      route_to("/foo/bar/baz").should have_route(:controller => "foo", :action => "bar", :id => "baz")
    end
    
    it "should be able to set :controller with #to" do
      Merb::Router.prepare do
        match("/:action").to(:controller => "users")
      end
      
      route_to("/show").should have_route(:controller => "users", :action => "show")
    end
    
    it "should be able to combine multiple named variables into a param" do
      Merb::Router.prepare do
        match("/:foo/:bar").to(:controller => ":foo/:bar")
      end
      
      route_to("/one/two").should have_route(:controller => "one/two", :foo => "one", :bar => "two")
    end
    
    it "should be able to overwrite matched named variables in the params" do
      Merb::Router.prepare do
        match("/:foo/:bar").to(:foo => "foo", :bar => "bar")
      end
      
      route_to("/one/two").should have_route(:foo => "foo", :bar => "bar")
    end
    
    it "should be able to block named variables from being present in the params" do
      Merb::Router.prepare do
        match("/:foo/:bar").to(:foo => nil, :bar => nil)
      end
      
      route_to("/one/two").should have_route(:foo => nil, :bar => nil)
    end
    
  end
  
  describe "a route with variables spread across match blocks" do
    
    it "should combine the path conditions from each match statement" do
      Merb::Router.prepare do
        match("/:foo") do
          match("/:bar").register
        end
      end
      
      route_to("/one/two").should have_route(:foo => "one", :bar => "two")
    end
  end
  
end