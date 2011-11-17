require 'json'
require 'ostruct'
require 'libvirt'
require 'xmlsimple'

class SimpleCloud
  attr_reader :instances
  attr_reader :images
  
  def initialize(config)
    @images = config['images']
    @instances = {}
    @nodes = config['nodes'].map { |n| OpenStruct.new n }
    
    @nodes.each do |node|
      node.free_memory = node.memory
      node.instances = []
      node.connection = Libvirt::open("qemu+ssh://#{node.ip}/system")
    end    
  end
  
  def create(image, memory)
    node = @nodes.find { |n| n.free_memory >= memory}
    
    raise ArgumentError("Not enough memory") if node.nil?
    
    xml = "TODO"
    
    
    node.free_memory -= memory
    virt_instance = node.conn.create_domain_linux(xml)
    
    instance = OpenStruct.new
    instance.inst = virt_instance
    instance.node = node
    instance.memory = memory
    instance.image = image
    instance.id = "#{node.ip}/#{virt_instance.id}"
    
    instance.mac = (XmlSimple.xml_in x.xml_desc)['devices'][0]['interface'][0]['mac'][0]['address']
    
    node.instances << instance
    @instances[instance.id] = instance
    
    instance.id
  end
  
  def destroy(instance_id)
    instance = @instances[instance_id]
    instance.inst.destroy
    instance.node.free_memory += instance.memory
    instance.node.instances -= instance    
    @instances.delete(instance_id)
  end
end