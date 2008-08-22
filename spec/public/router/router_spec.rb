require File.join(File.dirname(__FILE__), "spec_helper")

describe Merb::Router do

  describe "#match" do
    
    it "should raise an error if the routes were not compiled yet" do
      lambda { Merb::Router.match(simple_request) }.should raise_error(Merb::Router::NotCompiledError)
    end
    
    it "should choose the correct route when multiple routes are defined" do
       Merb::Router.prepare  do |r| 
         r.match("/denver").to(:controller => "one")
         r.match("/houston").to(:controller => "two")
       end
       
       route_to("/denver").should have_route(:controller => "one")
       route_to("/houston").should_not have_route(:controller => "one")
    end
  end

end