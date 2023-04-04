// 默认的过期时间
local expiry = '876600h';
/*
expect input: {is_ca: true, common_name: "vulcanus.io", }
*/
local params=std.extVar('params');
# fork from params
// 业务名称或者对外的域名
local common_name = params.common_name;
local hosts = params.hosts;
local is_ca = params.is_ca;
// https://www.cnblogs.com/iiiiher/p/8085698.html
local country = 'CN';
local city = 'CD';
local location = 'Sichuan';
{
  CN: common_name,
  hosts: hosts,
  key: {
    algo: 'rsa',
    size: 2048,
  },
  names: [
    {
      C: country,
      ST: city,
      L: location,
    },
  ],


} + (
  // 这段就有意思了，一定要知道CA字段需要生活在顶级json cope
  if is_ca then {
    CA: {
      expiry: expiry,
    },
  } else{} // 这里最后一定要给一个空的obj，新的版本会报错的
)