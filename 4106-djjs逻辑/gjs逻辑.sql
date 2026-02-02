SELECT * FROM gjs_user_info t WHERE t.user_account = 'oper01'; -- 用户表，登陆
SELECT * FROM gjs_auth_info;-- 菜单权限表，权限
SELECT * FROM gjs_user_auth;-- 用户权限关系表
SELECT * FROM gjs_account_info;-- 账户信息表，结算行，账户管理
SELECT * FROM gjs_project_info;-- 项目信息，项目管理
SELECT * FROM gjs_fund_of_remittance;-- 项目汇入计划
SELECT * FROM gjs_remittance_of_funds t WHERE t.is_confirmed != '0' ORDER BY t.gjs_create_time desc;-- 资金汇入流水信息 account_id 464a7b20daef4033983e9d1b5fd6310d 汇入流水 初始页面显示 汇入资金认定
-- 待确认款项 SELECT * FROM gjs_remittance_of_funds t WHERE t.is_confirmed != '1';
-- 查看认定
SELECT * FROM gjs_pipeline_of_planning t WHERE t.account_id = '464a7b20daef4033983e9d1b5fd6310d'; -- remittance_id eba26ed8feff41bdb15194a64d13efae 流水计划关联表
SELECT * FROM gjs_fund_of_remittance t WHERE t.remittance_id = 'eba26ed8feff41bdb15194a64d13efae'; -- 汇入计划表 查看页面显示
SELECT * FROM GJS_RELATION_REPATRIATION t WHERE t.remittance_id = 'eba26ed8feff41bdb15194a64d13efae';-- 汇入汇出关联表 REPATRIATION_ID GJS1585814231481
SELECT * FROM gjs_repatriation_of_funds t WHERE t.outer_trade_no = 'GJS1585814231481';-- 资金汇出表 project_id 也可查询
SELECT * FROM gjs_statement_of_funds;-- 资金流水明细
SELECT * FROM gjs_account_statement_file; -- 对账单信息
SELECT * FROM gjs_accounting_check;-- 账务核对
SELECT * FROM gjs_interest_calculation;-- 利息核算数据
SELECT * FROM gjs_pipeline_of_planning t WHERE t.capital_uses LIKE '%1%';-- 利息核算来源数据，流水计划关联表
SELECT * FROM gjs_fruits_business t ORDER BY t.gjs_create_time desc;-- 孳息核算数据

-- 计算日均余额start  gjs_accounting_check 孳息核算来源数据
select distinct a.*,h.bank_name as bankName,h.opst_account_bank_name as opstAccountBankName 
    from (select g.bank_account_no,
    sum(g.system_account_balance) as systemAccountBalance from gjs_accounting_check g where g.checked_result = '0'
		AND g.GJS_CREATE_TIME >= to_date('2020-08-01', 'yyyy-MM-dd') 
		AND g.GJS_CREATE_TIME <= to_date('2020-08-02', 'yyyy-MM-dd') 
		group by g.bank_account_no) a
    left join gjs_accounting_check h on a.bank_account_no = h.bank_account_no
    order by a.systemAccountBalance DESC;
-- 计算日均余额end

-----------------------------------定时-------------------------------------------------------
SELECT * FROM Times_Tatistics_Tj;-- 每日0点统计信息，日/周/月/年
-- 每分钟对登陆用户判断超时，redis超时 set login_status='3'
SELECT * FROM gjs_user_info t WHERE t.login_status = '1';-- 1/2/3 登录/锁定/未登录
-- 每15分钟查账户信息去调北登接口查资金汇入流水，merge into gjs_remittance_of_funds
SELECT * FROM gjs_account_info t WHERE t.exec_status = '1';
-- 每5分钟调北登接口查询一次资金账户余额，update gjs_account_info set amount
-- 每隔10分钟调北登接口查询资金汇出状态，根据 OUTER_TRADE_NO
SELECT * FROM gjs_repatriation_of_funds t WHERE t.repatriation_status = '1';-- 1/2/3/4 处理中/成功/失败/作废，数据为系统新增
-- 返回值处理，状态T成功->更新gjs_account_info.SYS_AMOUNT-=gjs_repatriation_of_funds.发生额，新增流水 gjs_statement_of_funds
-- WITHDRAWAL_SUBMIT->W处理中
-- WITHDRAWAL_FAILED->F失败 repatriation_status = '3'，gjs_relation_repatriation.remittance_id is null 回滚汇出计划(gjs_fund_of_remittance 可用余额回滚add，汇出金额substract) else 回滚汇出金额(gjs_remittance_of_funds 待确认金额add，汇出金额substract)
-- 每天早上八点获取之前一天的对账单数据，从sftp上获取，更新表数据
-- 每隔五分钟查询一次资金计划表，将过期的计划设置为作废 set into_state = '3'
SELECT * FROM gjs_fund_of_remittance t WHERE t.into_state = '0' AND t.is_save = '0'; -- into_state 0/1/2/3 待匹配/已匹配/部分匹配/作废 is_save 0/1 否/是
-- 每隔五分钟查询一次资金汇出，更新过期的汇出状态为作废，set repatriation_status = '4'
select * from gjs_repatriation_of_funds t  where t.pay_deadline < trunc(sysdate) and t.repatriation_status not in ('1','2','3','4','13','25');
-- 每天23:45查询一次账户信息表表，gjs_account_info 将数据同步到账务核对表中 insert into gjs_accounting_check