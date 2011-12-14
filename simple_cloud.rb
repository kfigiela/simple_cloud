# encoding: utf-8
# require 'json'
require 'ostruct'
require 'libvirt'
require 'erb'
require 'xmlsimple'
require 'net/sftp'
require 'net/ssh'

class Node < OpenStruct
  def connection
    connection = Libvirt::open("qemu+ssh://#{self.ip}/system")
    yield connection
    connection.close
  end
end

class Instance < OpenStruct
  def inst
    self.node.connection do |c|
      yield (c.lookup_domain_by_name self.id)
    end
  end
end

class SimpleCloud
  attr_reader :images
  
  def assign_serial
    @serial +=1 
    @serial
  end
  
  def initialize(config)
    @images = config['images']
    @instances = {}
    @nodes = config['nodes'].map { |n| Node.new n }
    @serial = 0
    @nodes.each do |node|
      node.free_memory = node.memory
      node.instances = []
    end    
  end
  
  def create(image, memory)
    node = @nodes.find { |n| n.free_memory >= memory}
    
    raise ArgumentError("Not enough memory") if node.nil?
    
    xml = ERB.new File.read("instance.xml.erb")
    
    
    node.free_memory -= memory
    
    instance = Instance.new
    instance.node = node
    instance.memory = memory
    instance.image = image
    instance.id = "i%x" % assign_serial    
    

    instance.image_file = node.imagepath + instance.id    
    Net::SFTP.start(node.ip, 'root') do |sftp|
      sftp.upload!(@images[image], instance.image_file)
    end

    node.connection do |connection| 
      inst = connection.create_domain_linux(xml.result(binding))
      instance.mac = (XmlSimple.xml_in inst.xml_desc)['devices'][0]['interface'][0]['mac'][0]['address']
    end
    instance.ip = nil
    
    node.instances << instance
    @instances[instance.id] = instance
    
    instance.id
  end
  
  def instance_ip instance
    if instance.ip.nil? 
      Net::SSH.start(instance.node.ip, 'root') do |ssh|
        arp = ssh.exec!('arp -an')
        matches = arp.match Regexp.new '\((\d+\.\d+\.\d+.\d+)\) at (%s)' % instance.mac
        instance.ip = matches[1] unless matches.nil?
      end

    end
    
    instance.ip
  end
  
  def destroy(instance_id)
    instance = @instances[instance_id]
    instance.inst { |inst| inst.destroy }
    instance.node.free_memory += instance.memory
    instance.node.instances -= [instance]
    @instances.delete(instance_id)
    
    Net::SFTP.start(instance.node.ip, 'root') do |sftp|
      sftp.remove!(instance.image_file)
    end
  end
  
  def instances
    @instances.values.map do |instance|
      {
        image: instance.image,
        memory: instance.memory,
        id: instance.id,
        mac: instance.mac,
        ip: (instance_ip instance)
      }
    end
  end
  
end
