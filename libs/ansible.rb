######################## Additional Helpers ##############################
# All credits to https://stackoverflow.com/questions/9381553/ruby-merge-nested-hash
class ::Hash
  def deep_merge(second)
      merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      self.merge(second, &merger)
  end
end
#########################################################################

def match_ansible_vars(path)
  values = YAML.load_file(path)
  if !values
    values = {}
  end  
  case path
  when /inventory\/[^\/]*\/group_vars\/(?<group_name>[^\/]*)\/(?<file_name>.*).yml/
    group_name = $~[:group_name] 
    return [{ "#{group_name}": values }, {}]
  when /inventory\/[^\/]*\/host_vars\/(?<group_name>[^\/]*)\/(?<file_name>.*).yml/
    group_name = $~[:group_name] 
    return [{}, { "#{group_name}": values }]
  when /inventory\/[^\/]*\/group_vars\/(?<file_name>.*).yml/
    return [values, {}]
  when /inventory\/[^\/]*\/host_vars\/(?<host_name>.*).yml/
    host_name = $~[:host_name] 
    return [{}, { "#{host_name}"=> values }]
  end
end

def match_ansible_vars(path)
  values = YAML.load_file(path)
  if !values
    values = {}
  end  
  case path
  when /inventory\/[^\/]*\/group_vars\/(?<group_name>[^\/]*)\/(?<file_name>.*).yml/
    group_name = $~[:group_name] 
    return [{ "#{group_name}": values }, {}]
  when /inventory\/[^\/]*\/host_vars\/(?<group_name>[^\/]*)\/(?<file_name>.*).yml/
    group_name = $~[:group_name] 
    return [{}, { "#{group_name}": values }]
  when /inventory\/[^\/]*\/group_vars\/(?<file_name>.*).yml/
    return [values, {}]
  when /inventory\/[^\/]*\/host_vars\/(?<host_name>.*).yml/
    host_name = $~[:host_name] 
    return [{}, { "#{host_name}"=> values }]
  end
end

def get_hosts_ini_dict(hosts_ini)
  dict = {}
  hosts_ini.each { |group, value|
    host = value
    if value.is_a?(Hash)
      host = value.keys[0]
    end

    group_val = group.split(':')[0]

    if dict.has_key?(host)
      dict[host].push(group_val)
    else
      dict[host] = [group_val]
    end
  }
  return dict
end

def get_ansible_groups(hosts_ini)
  dict = {}
  hosts_ini.each { |group, value|
    host = value
    if value.is_a?(Hash)
      host = value.keys[0]
    end

    if dict.has_key?(group)
      dict[group].push(host)
    else
      dict[group] = [host]
    end
  }
  return dict
end

def get_all_nested_groups(acc, dict, host)
  if dict.has_key?(host)
    new_groups = dict[host]
    return new_groups.reduce(new_groups) { |acc, group| acc + get_all_nested_groups([], dict, group) }
  end
  return acc
end

def merge_vars(group_vars, host_vars, hosts_ini)
  groups_dict = get_hosts_ini_dict(hosts_ini)
  merged = host_vars.reduce({}) { |acc,(host,val)| 
    acc[host] = val
    groups = get_all_nested_groups([], groups_dict, host)
    groups.each { |group|
      gvars = group_vars[group.to_sym]
      if !gvars
        gvars = {}
      end
      acc[host] = acc[host].deep_merge(gvars)
    }
    acc
  }
  return merged
end

def load_ansible_inventory(inventory_path)
  hosts_ini = IniFile.load(File.join($abs_root_path, "inventory/#{$inventory}/hosts.ini")) 
  init = {group_vars: {}, host_vars: {}}
  reduced = Dir["inventory/#{$inventory}/**/*.yml"].reduce(init) { |acc,fp|
    group_vars, host_vars = match_ansible_vars(fp)
    acc[:group_vars] = acc[:group_vars].deep_merge(group_vars)
    acc[:host_vars] = acc[:host_vars].deep_merge(host_vars)
    acc
  }

  host_vars_with_ansible_vars = hosts_ini["all"].deep_merge(reduced[:host_vars])
  return [merge_vars(reduced[:group_vars], host_vars_with_ansible_vars, hosts_ini), hosts_ini]
end
