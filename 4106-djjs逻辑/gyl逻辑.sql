21CFSC0434
21CFSC0430
21CFSC0426
SELECT * FROM djjs_fund.fund_account t WHERE t.product_code IS NOT NULL AND t.product_code != ' ' ORDER BY t.fund_account DESC;
SELECT * FROM djjs_info.inford_product_basic t WHERE t.bond_id = '2012302791';-- bond_code GD202012300001

-- #请求状态 TransStatus:0-未报,1-已报,2-成功,3-失败,4-待撤,5-撤销,7-待冲正,8-已冲正,9-处理中
-- 调用银企时，新增请求流水 FundBankTransfer BankNo=银行编号，BankProCode=银企直联简码 czb，BankAccount=Request.BankAccount，FundAccount=Request.FundAccount，TransStatus=0，RepeatTimes=0，TransType=enum.code 100001，FundBillNo=Request.BizNo，InnerBillNo=系统生成 seq
-------------------------------------------------------------- C0075071 产品结算账户开户 execProductAccountOpen
-- 请求报文：{"requestNo":"3379ba5c-457d-473d-a152-954c12212b16","protocol":"DUBBO","service":"C0075071","version":"1.0","partnerId":"C0075","context":{"bondCode":"21CFSC0480","bondShortName":"21浙商供应链SC0480","payChannelType":"czb","productAccountStatus":"1"}}
-- 调用浙商进行开户：100001 90030019，销户：100002 90030020
-- 开户
insert into djjs_fund.fund_account (FUND_ACCOUNT, MEM_CODE, ACCOUNT_NAME, INFO_RECORD_ACCOUNT, CURRENCY, SUBJECT_CODE, ACCOUNT_TYPE, BALANCE_DIRECTION, FUND_ACCOUNT_STATUS, ACCNT_FLAG, ID_KIND, ID_NO, IS_SECURITY_ACCOUNT, BANK_CLIENT_NO, PAY_CHANNEL_ID, ACCOUNT_OPEN_DATE, ACCOUNT_CANCEL_DATE, ENTRY_FORM, INPUT_DATE, INPUT_TIME, INPUT_OPER_ID, INPUT_OPER_NAME, UPDATE_DATE, UPDATE_TIME, REMARK, RESERVE1, RESERVE2, RESERVE3, RESERVE4, PRODUCT_CODE, PRODUCT_NAME, BANK_CLIENT_NAME)
values ('P00000000000271', null, ' ', ' ', 'CNY', '200040000', '3', '2', '1', '2', null, null, '2', '705340355', 'czb', 20210317, 20210317, '0', 20210317, 171912, null, null, 20210317, 172800, null, null, '61372110936572526592', '61372113153895530496', null, '21CFSC0480', '21浙商供应链SC0480', '21浙商供应链SC0480');
-- 销户
UPDATE DJJS_FUND.FUND_ACCOUNT fa SET fa.FUND_ACCOUNT_STATUS = '2', fa.RESERVE3 = '银行返回 Buslogid', fa.UPDATE_DATE = to_number(to_char(sysdate, 'yyyyMMdd')),
fa.UPDATE_TIME = to_number(to_char(sysdate, 'hh24miss')) WHERE 1 = 1 AND fa.BANK_CLIENT_NO = 'fund_account.BANK_CLIENT_NO';
update cash_bill_order t set t.reserve1 = '1' where t.bank_client_no = '';-- 来账指令不可原路退回

-- FUND_ACCOUNT P00000000000271 执行存储过程：AP_SERIAL_COUNTER_GET p_exchange_id=0000000 p_serial_counter_no=11000504  执行 AccountUtils.java main函数
-- BANK_CLIENT_NO 705340355 银行客户号	银行返回
-- 20210317 sysdate 日期	171912+172800 sysdate 时间
-- RESERVE2 61372110936572526592 开户接口返回流水号	银行返回
-- RESERVE3 61372113153895530496 销户接口返回流水号	银行返回，开户时为空
-- PRODUCT_CODE 21CFSC0480 产品编号	接口传
-- PRODUCT_NAME 21浙商供应链SC0480 产品简称	接口传
-- BANK_CLIENT_NAME 21浙商供应链SC0480 银行客户号名称	银行返回
INSERT INTO DJJS_FUND.ACCOUNT_BALANCE
(FUND_ACCOUNT, MEM_CODE, ACCOUNT_NAME, ACCNT_TYPE, CURRENCY, SUBJECT_CODE, BALANCE_DIRECTION, 
BEGIN_ACCOUNT_BALANCE, ACCOUNT_BALANCE, FREEZE_BALANCE, USABLE_BALANCE, FETCH_BALANCE, UPDATE_DATE, UPDATE_TIME, MD5_RESULT)
VALUES('FUND_ACCOUNT.fund_account', null, ' ', '3', 'CNY', '200040000', '2', 0.0, 0.0, 0, 0.0, 0, 
to_number(to_char(sysdate,'yyyymmdd')) , to_number(to_char(sysdate,'hh24miss')) , (select djjs_fund.ap_fund_md5_utils( 0.0 ||''|| 0.0 ||''|| 0) from dual)
);

-------------------------------------------------------------- C0075001 备案 execTRegNoticeInfo+ C0075011 产品信息 execTReceiveProductInfo 产品推送，由供应链接口推送，其中备案可重复推修改，产品不可，只能线下修改。
-- 备案：{"requestNo":"77f094dd-9e9a-48bf-a6b3-1c898c972e62","protocol":"DUBBO","service":"C0075001","version":"1.0","partnerId":"C0075","context":{"regNoticeCode":"8a8ad2ea76b8c5c60176ff7f37d00848","subMemCode":"81000154","trustAccount":"11111","regNoticeAmount":999.9999,"regNoticeNumber":"供应链债权融资计划[2021]第0015号","regNoticeStatus":"0"}}
-- 产品信息：{"requestNo":"a273a36f-8709-4ee3-a579-3509a0398e27","protocol":"DUBBO","service":"C0075011","version":"1.0","partnerId":"C0075","context":{"lzList":[],"fzList":[],"productBasicInstance":{},"infordProductBasic":{"bizId":"20210114SCGP0402","bondFullName":"浙商银行股份有限公司测试区块链供应链债权融资计划2021101","bondShortName":"21浙商供应链SC0402","bondCode":"21CFSC0402","bondScale":0,"regNoticeNumber":"供应链债权融资计划[2021]第0004号","bookManager":"81000154","bookManagerName":"浙商银行股份有限公司测试","publishModel":"2","bondType":"3","bankNo":"316331000018","bankName":"浙商银行总行会计核算中心","bankAccountNo":"3310010010120101039140","bankAccountName":"浙商银行股份有限公司广州分行","recordAccntNo":"RZ81000208","fundTransAccntNo":"301225620","fundTransAccntName":"21浙商供应链SC0402","fundTransBankName":"浙商银行","circulatingGround":"1","financierName":"繁花似锦","agentInitiator":"浙商银行股份有限公司测试","agentInitiatorCode":"81000154","leadManagerCode":"81000154","leadManagerName":"浙商银行股份有限公司测试","purchaseTotal":1.50,"subBeginDate":20210114,"subBeginTime":114025,"subEndDate":20210114,"subEndTime":153841,"contactTel":"100","contactName":"11111111"},"productElementInstance":{},"infordProductElement":{"bondTerm":"356","termUnit":"3","faceValue":100,"valueCurrency":"1","interestMode":"1","rateType":"1","valueDate":20210115,"maturityDate":20220106,"registrDate":20210115,"isRightsProduct":"2","couponRate":96.93,"publishPriceModel":"1","appType":"4"},"productPublishInstance":{},"infordProductPublish":{"infordOfferedType":"1","publishDateB":20210114,"publishDateE":20210114,"noticeDate":20210118,"consignPayEndDate":20210115},"stageRepayInfoInstance":{},"productRightsInstance":{}}}

-------------------------------------------------------------- C0075072 产品申购 execProductSubscribe，冻结	90030021
-- 请求报文：{"requestNo":"aef87264-ebec-4c97-a274-6894bb5ac822","protocol":"DUBBO","service":"C0075072","version":"1.0","partnerId":"C0075","context":{"bondCode":"21CFSC0480","bizCode":"20210317SCGP0480","settlementAmount":3.712043,"tradeAmount":3.889400,"payChannelId":"czb","recordAccntNo":"TZ81000251","settleType":"1"}}
-- #结算指令状态 OrderStatus：1-未生效，2-处理中，3-处理成功，4-处理失败，5-已撤销，6-冻款成功，7-划款失败，8-解冻成功，9-解冻失败
-- #资金操作类型 FundOpType：1:冻结，2:解冻，3:冻结划扣，4:划转，5:提款
-- 生成 djjs_info.settle_bond 数据 OrderStatus=6 冻款成功，投资人 贷方，融资人 借方
-- 生成 挂牌冻结指令 djjs_info.SettleBondFund 数据 OrderStatus=3 成功，PayerMemCode 付款方 settle_bond.CreditMemCode，PayeeMemCode ""，新生成 ExternalTradeNo，FundOpType=1
-- #供应链资金清算指令状态 SettleClearStatus：0:待清算，1：清算成功，2:清算失败，3:待处理，4:处理中，5:处理成功，6：处理失败，7：暂停，8：异常
-- 生成挂牌冻结资金清算指令  djjs_fund.ChainSettleFund SettleClearStatus=5 处理成功，付款方和收款方都是非产品户，生成挂牌冻结资金执行指令 djjs_fund.ChainSettleFundExec SettleExecStatus=d 处理成功
-- 调用浙商进行冻结：100010 90030021
-- 生成余额冻结明细 
insert into FundFreezeBalance AccountNo=chainSettleFund.PayerFundAccount 付款方数据 ExternalTradeNo=chainSettleFund.ExternalTradeNo FreezeId=chainSettleFund.SettleFundId，FreezeState=1;
-- 生成一条付款方数据，冻结流水 
insert into FundFreezeSerial：MemCode=chainSettleFundExec.PayerMemCode，FundAccount=chainSettleFund.PayerFundAccount

-------------------------------------------------------------- C0075074 产品申购结果接收 execProductPurchaseResult，冻结划扣/解冻	90030022/90030023
-- 请求报文：{"requestNo":"a8179231-e398-48a0-a74c-29a5e68d048d","protocol":"DUBBO","service":"C0075074","version":"1.0","partnerId":"C0075","context":{"bondCode":"21CFSC0469","purchaseResult":"7","bondScale":3.889200,"settlementAmount":3.672572}}
-- if 申购成功
-- a)更新产品信息中的实际挂牌金额。产品状态改为申购成功 
update infordProductBasic set BjsIdentify=7 申购完成，BondScale=实际挂牌金额
-- b)生成本金偿还计划，供应链项目为贴现式，本金偿还计划只有一条，偿还日期为到期日，偿还本金为实际挂牌金额 
update InfordProductElement RepayModel=到期一次性偿还本金
insert into InfordStageRepayInfo
-- c)根据申购结果，逐条生成冻结划转指令发送至资金结算。
-- 查询数据
select * from djjs_info.SettleBond OrderStatus=6
-- 生成挂牌冻结划扣指令 
insert into djjs_info.SettleBondFund OrderStatus=1 未生效，PayerMemCode 付款方 settle_bond.CreditMemCode，PayeeMemCode ""，新生成 ExternalTradeNo，FundOpType=3，收款方产品户
-- 生成挂牌冻结划转资金清算指令 
insert into djjs_fund.ChainSettleFund SettleClearStatus=5 处理成功，付款方是非产品户，收款方是产品户，生成挂牌冻结划扣资金执行指令 djjs_fund.ChainSettleFundExec SettleExecStatus=d 处理成功
-- 调用浙商进行冻结划扣：100011 90030022
-- 冻结划扣记账（仅记录产品户的账）
-- 单边记账：技术调账记账、入金调账记账 记账请求指令表
insert into djjs_fund.acct_order acctNo=functionNo=acctType 27，ChainSettleFundExec.ExternalTradeNo，AccountOrderStatus=0 #0/1/2 待处理/成功/失败，seq获取 AccountOrderNo
insert into djjs_fund.acct_order_detail t WHERE t.account_order_no = 'AccountOrderNo'; -- 记账请求分录表 两条数据，一条收款方为产品户记贷方金额，一条大账户核算账户记借方金额
-- 更新账户余额 AccountBalance：根据 acct_order_detail 的两条分录核算账号更新 AccountBalance 余额，用于提款 17:30验资校验 和 账户出金时使用 
update AccountBalance set ACCOUNT_BALANCE+=occurAmount，USABLE_BALANCE+=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance+#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance+#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 生成两条账务流水，账务余额处理
insert into djjs_fund.acct_serial acct_order.AccountOrderNo，ExternalTradeNo=acct_order.ExternalTradeNo，FundAccount 两个账号（产品户+大账户），OpenMemCode=fund_account.memcode 参与人账号
-- 更新记账请求指令状态
update djjs_fund.acct_order set AccountOrderStatus=1 where AccountOrderNo=acct_order.AccountOrderNo
-- #冻结状态 FreezeState：1：已冻结，2:已解冻，3:已冻结划扣
-- 更新余额冻结明细表 
update FundFreezeBalance set FreezeState=3, RemainingAmount-=chainSettleFundExec.SettlementAmount 金额和状态，djjs_fund.ChainSettleFundExec SettleExecStatus=d 处理成功 
-- #付款方状态 PayStatus：1-N/A，2-未检查，3-结算中，4-结算完成
update djjs_info.SettleBond set OrderStatus=2，PayStatus=4
update djjs_info.SettleBondFund set OrderStatus=3
-- d)同时生成一条挂牌债权结算指令，付款方为产品资金账户、收款方为挂牌管理人预留募集资金账户、结算金额为实际结算金额、结算日为缴款截止日，一般为t+1。
-- 生成挂牌提款指令 
insert into djjs_info.SettleBondFund OrderStatus=1 未生效，PayerMemCode ""，PayeeMemCode ""，新生成 ExternalTradeNo，FundOpType=5，付款方产品户，收款方银行信息为主承信息
-- 生成挂牌提款资金清算指令 
insert into djjs_fund.ChainSettleFund SettleClearStatus=0 待清算，FundOpType=5，付款方是产品户，收款方是非产品户，生成挂牌提款资金执行指令，付款方银行信息为产品户信息，收款方银行信息为产品信息中的主承信息ipb.bank_no/bank_name/bank_account_no/bank_account_name
update djjs_info.SettleBondFund set OrderStatus=2 处理中
-- else 申购失败
-- a)更新产品信息中的实际挂牌金额。产品状态改为申购失败 update infordProductBasic set BjsIdentify=8
-- b)根据需解冻的冻结记录，逐条向资金结算发送资金解冻指令，调用浙商进行解冻
-- c)更新djjs_info.SettleBond OrderStatus=8 解冻成功，PayStatus=4 结算完成，更新djjs_info.SettleBondFund OrderStatus=3 处理成功
-- d)注销产品户	90030020

--------------------------------------------------------------- C0075075 产品状态接收 execProductStatusResult 上市 
-- 请求报文：{"requestNo":"e2d6a4c1-2ffa-46f3-a818-008b795ae33c","protocol":"DUBBO","service":"C0075075","version":"1.0","partnerId":"C0075","context":{"bondCode":"21CFSC0405","bjsIdentify":"3"}}
-- 1.产品信息状态修改 
update infordProductBasic set BjsIdentify = 3 ，只接收上市成功的状态
-- 2.债权过户并且生成信息记载流水 查询 SettleBond 数据 where BusiType=1 and OrderStatus=2 and PayStatus=4
-- 根据 bondCode+bondId 确认投资人和融资人的持仓信息 merge into InfordAmount
-- 记录流水信息 
insert into InfordInformationRecord
update SettleBond set OrderStatus=3
-- 生成信息记载确认单，bill.bill_type=52
-- 3.新增存续期要素 
insert into InfordProductSurvival

--------------------------------------------------------------- C0075076 转让 execTransferSupplyChains 
-- 请求报文：{"requestNo":"ddc01d66-dae0-4419-bb03-3a53c0eade07","protocol":"DUBBO","service":"C0075076","version":"1.0","partnerId":"C0075","context":{"bizCode":"SCFPSR202012290001","busiType":"2","bondCode":"20CFSC0385","bondShortName":"20浙商供应链SC0385","tradeAmount":1.000000,"settlementAmount":9997.90,"initDate":1609171200000,"dealDate":1609171200000,"creditSecondMemCode":"81000143","debitSecondMemCode":"81000144","creditAccountBankName":"","debitAccountBankName":"","creditBankName":"","debitBankName":"","creditAccountBankNo":"","debitAccountBankNo":"","creditLargeBankNo":"","debitLargeBankNo":"","creditAccount":"TZ81000143","debitAccount":"TZ81000144","settleType":"1"}}
-- #复核状态 AuditStatus 1--待复核 2--复核通过 3--复核不通过
-- 生成债券结算指令：
insert into SettleBond bizCode 由接口输入，借方=付券方=转让方，贷方=收券方=受让方，AuditStatus=2，OrderStatus=2，PayStatus=2（可能存在与1/2号系统定时处理债券清算并发问题）
-- 根据 bondId+借/贷方方账号更新持仓信息 
update InfordAmount， 借贷为同一人借方账户，更新借方可用（可用 EnableValue-发生额），待付 （ToPayValue+发生额）
-- 记录流水信息 
insert into InfordInformationRecord，SettleBond 借贷同一人由可用到待付
-- 生成转让划款指令 
insert into djjs_info.SettleBondFund 数据，付款方=贷方=受让方，收款方=借方=转让方，FundOpType=4，两个非产品户，OrderStatus=1
-- 生成转让划转资金清算指令 
insert into djjs_fund.ChainSettleFund SettleClearStatus=5 处理成功
-- 生成转让划扣资金执行指令 
insert into djjs_fund.ChainSettleFundExec SettleExecStatus=d 处理成功
-- 调用浙商进行转账	100020 90030024 
update SettleBond set OrderStatus=3，PayStatus=4
update SettleBondFund set OrderStatus = 3
-- 转让结果处理，记录流水信息 
insert into InfordInformationRecord，SettleBond 数据来源， 借方待付到贷方可用
-- 更新 InfordAmount 借方待付（ToPayValue-发生额）merge into InfordAmount 贷方可用（EnableValue+发生额）
-- 生成信息记载确认单，bill.bill_type=52

-----------------------------------------------------------定时清算 0 30 17 * * ? start -------------------------------------
-- **************************************挂牌提款 start
-- 查询 djjs_fund.ChainSettleFund 挂牌业务，FundOpType=5 提款，SettleClearStatus=0 待清算，settlement_date=d+1 的数据
-- #付息兑付计划状态 IntePayStatus：未开始 1，已通知 2，划款中 3，划款成功 4，划款失败 5，已完成 6，延期 7，延期完成 8，失败 9，延期失败 A
-- #供应链资金清算指令状态 Reserve SettleClearStatus：0:待清算，1：清算成功，2:清算失败，3:待处理，4:处理中，5:处理成功，6：处理失败，7：暂停，8：异常
-- 调用浙商查产品户余额：100018 40000101
-- 验资，查询的余额>=结算金额 && 付款方即产品户余额 AccountBalance.余额（冻结划扣记账时加的余额） >=结算金额
update djjs_fund.ChainSettleFund set SettleClearStatus=1 清算成功
update InterestPayPlanInfo set IntePayStatus=3 划款中，Reserve=3 待处理
-- **************************************挂牌提款 end
-- **************************************兑付 start
-- 查询 djjs_fund.ChainSettleFund busi_type = '4' and settle_clear_status ='0' and settlement_date = to_number(to_char(sysdate +1, 'yyyyMMdd'))
-- 调用浙商查产品户余额：100018 40000101
-- 验资，查询的余额>=结算金额 && 付款方即产品户余额 AccountBalance.余额（入金流水时加的余额） >=结算金额
update djjs_fund.ChainSettleFund set SettleClearStatus=1 清算成功
update InterestPayPlanInfo set Reserve=1 清算成功 where IntePayStatus=3 划款中
-- **************************************兑付 end
-----------------------------------------------------------定时清算 0 30 17 * * ? end -------------------------------------

-----------------------------------------------------------定时结算 0 30 9 * * ? start -------------------------------------
select * from ChainSettleFund where busi_type = '1' and fund_op_type = '5' and need_audit ='0' and settle_clear_status  = '1' and settlement_date = to_number(to_char(sysdate, 'yyyyMMdd')) or busi_type = '4' and need_audit ='0' and settle_clear_status  = '1' and settlement_date = to_number(to_char(sysdate, 'yyyyMMdd')) or ...;
-- *********************************** 挂牌过程 start 
-- 生成挂牌资金执行指令 
insert into djjs_fund.ChainSettleFundExec 
-- /**#出入金明细状态 CashFlowStatus:1-生成记录,2-超时,5-处理成功,6-处理失败,11-记账失败,12-待审核,13-审核通过,14-审核拒绝,15-审核失败-待回执，19-处理中，20-已冲正*/
--********************************** 校验出入金明细中是否存在记录，更新余额，新增出入金记录，出金记账
-- 检验余额（可用余额>=发生额），插入出入金明细 
insert into cashExchangeDetail	FundAccount=付款方为产品户，付款方银行信息为结算大账户绑卡信息，收款方银行信息为产品信息中的主承信息ipb.bank_no/bank_name/bank_account_no/bank_account_name，CashFlowStatus=1
-- 更新账户余额(产品户资金账号) AccountBalance，出金减钱（冻结划扣记账时加的余额）
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '产品户' for update; 
-- 更新发生额 ACCOUNT_BALANCE-=occurAmount，USABLE_BALANCE-=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance-#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance-#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 出金记录账务流水 对外部账户的操作 
insert into acct_serial AcctSerial，fund_account=产品户，OpstAccount=大账户结算账号，记借方金额
-- 调用浙商进行产品户出款	100014 90030026，成功则更新 
update cashExchangeDetail set BankBillNo=银行返回，CashFlowStatus=5，Remark='出金成功！'

-- 核算账户余额变更，记录核算账户余额，FundAccount=大账户，AccountBalance，出金减钱（冻结划扣记账时加的余额）
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '大账户结算账号' for update; 
-- 更新发生额 ACCOUNT_BALANCE-=occurAmount，USABLE_BALANCE-=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance-#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance-#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 记录账务流水 对外部账户的操作 
insert into acct_serial AcctSerial fund_account=大账户结算账号 OpstAccount=产品户，记贷方金额

update djjs_fund.ChainSettleFundExec set SettleExecStatus=d 处理成功 BankBillNo=银行返回 
update ChainSettleFund set SettleClearStatus=5
-- 挂牌提款和付息兑付需要告知信息记载
-- (BusiType=1 && FundOpType=5) || BusiType=4 时
update SettleBondFund set OrderStatus = 3
update InfordProductBasic set BjsIdentify=2 已缴款
-- 生成付息兑付计划 上传文件，发送付息兑付计划到主流程 C0075057 IScfpService：execPromotionOfInterestPaymentPlan
insert into bill bill.bill_type=56
-- *********************************** 挂牌过程 end 
-- *********************************** 兑付过程 start 
-- 生成兑付资金结算执行指令 
insert into djjs_fund.ChainSettleFundExec SettleExecStatus=a 待处理，ReconcileStatus=1 未对账
-- 更新账户余额(产品户资金账号) AccountBalance，出金减钱（入金流水时加的余额）
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '产品户' for update; 
-- 更新发生额 ACCOUNT_BALANCE-=occurAmount，USABLE_BALANCE-=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance-#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance-#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 转账记录账务流水 AcctType=15 对外部账户的操作 
insert into acct_serial AcctSerial，fund_account=产品户，OpstAccount=大账户结算账号，记借方金额
-- 调用浙商进行转账	100020 90030024 
/**
     * 转账成功记账
     *  付款方是产品户，收款方不是产品户，则记录付款方核算账户记减账，记录核算户流水（核算账户到产品户）
     *  付款方是产品户，收款方是产品户，则记录收款方产品户记加账，记录收款方产品户流水(收款方到付款方产品户)
     *  付款方不是产品户，收款方是产品户，则记录收款方产品户加账，核算户加账，记录收款方产品户流水（产品户到核算户，核算户到产品户）
     *  付款方不是产品户，收款方也不是产品户，不记录
     *
     * */
-- 核算账户余额变更，记录核算账户余额，FundAccount=大账户，AccountBalance，出金减钱（入金流水时加的余额）
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '大账户结算账号' for update; 
-- 更新发生额 ACCOUNT_BALANCE-=occurAmount，USABLE_BALANCE-=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance-#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance-#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 记录账务流水 AcctType=15 对外部账户的操作 
insert into acct_serial AcctSerial fund_account=大账户结算账号 OpstAccount=产品户，记贷方金额
update djjs_fund.ChainSettleFundExec SettleExecStatus=d 处理成功 BankBillNo=银行返回
update ChainSettleFund set SettleClearStatus=5 处理成功
update SettleBondFund set OrderStatus = 3 处理成功
-- 更新付息兑付明细 
update InfordIntePayCalDetail set Reserve=IntePayStatus=4 划款成功
-- 获取业务类型为付息兑付、相同业务编号、指令状态为处理成功的处理金额合计
select sum(SETTLEMENT_AMOUNT) SETTLEMENT_AMOUNT from SETTLE_BOND_FUND where ...;
-- 查询相同业务编号，状态为划款中的付息兑付计划，获取兑付金额，如果合计金额=兑付计划金额，则生成 融资人利息/本金资金划转成功通知书 bill.bill_type=55
update InterestPayPlanInfo set IntePayStatus=6 已完成，Reserve=3 成功
-- 推送主流程系统融资人利息本金资金划转成功通知书 C0095052 IScfpService execReceiveProductAttachments
-- 校验存续期产品债券余额是否为零，若为零产品注销，不为零不进行注销
update InfordProductBasic set InfoProductSubStatus=5 注销，BjsIdentify=4 到期
-- 付息兑付完成后自动进行注销，添加复核通过记录
insert into InfordProductAudit BondId
-- 推送资金结算系统进行产品户销户，同时推送主流程系统产品到期 C0095075 IScfpService execProductStatusSynchronization

-- *********************************** 兑付过程 end 
-----------------------------------------------------------定时结算 0 30 9 * * ? end -------------------------------------

-----------------------------------------------------------定时查询(浙商)资金入账 0 0/15 * * * ? start -------------------------------------
-- 100003 90030025 查入金
-- #出入账标识 txntype，1-出账，2-入账
-- #对手方虚拟账号标识，oppzspsaflag 1-是，0-否
-- 入库银行账户明细表
insert into BankAccountDetail BankBillNo=银行流水号，PayChannelId=czb， Paycard** 付款方信息，ReceicardNo 收款方账号
-- 根据银行流水号和银行产品代码查询是否存在来账指令信息，存在则略过,只记录实户入账信息 txntype=2 且 oppzspsaflag=0（注：出现挂牌入金为实体户情况，与需求不符，多生成一笔挂牌记账）
-- #cashInstate=0/1/2/3/4/5/6	未入账/入账中/待调账/调账中/已调账/已核销/已退回 mergeFlag=0/1/2/3 未合并/合并中/被合并/合并
insert into CashBillOrder PayChannelId=czb，BankClientNo=交易本方虚拟账号（银行返回），BankBillNo=流水号，pay***=付款方信息，CashInState=0 未入账，MergeFlag=0 未合并，AuditStatus=5 （有疑问）
-- BankClientNo 虚拟产品户查询 FundAccount 信息，存在才能  根据账务明细信息，新增产品户余额、大账户余额
-- 执行入账的账务处理
-- cashBillOrder+fundAccount（产品户账户）+payWay（大账户核算账户）+BindAccount（大账户卡号）
/**#出入金明细状态 CASH_FLOW_STATUS:1-生成记录,2-超时,5-处理成功,6-处理失败,11-记账失败（出入金时，调用前置成功，余额更新成功、出入金明细成功，但记账失败）,12-待审核,13-审核通过,14-审核拒绝,15-审核失败-待回执，19-处理中，20-已冲正*/
-- 出入金明细新增一条 
insert into djjs_fund.cash_exchange_detail fundAccount=产品户， CashFlowName=2 入金，ReconcileStatus=1 未对账，生成新的 ExternalTradeNo，BankBillNo=cashBillOrder.BankBillNo，PaycardNo=BankAccount=cashBillOrder.PaycardNo，ReceicardNo=BindAccount.BankAccount，Recei***=BindAccount.***，CASH_FLOW_STATUS=5 
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '产品户' for update; 
-- 更新发生额 ACCOUNT_BALANCE+=occurAmount，USABLE_BALANCE+=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance+#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance+#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 返回值：AccountBalance.PreBalance=account_balance.AccountBalance, AccountBalance.AccountBalance=account_balance.AccountBalance+occurAmount(发生额)
-- 进行产品户记账操作，accounts_queue 中的金额和上面更新后的 account_balance 余额信息是一样的
-- 新增入账队列一条
insert into djjs_fund.accounts_queue CashFlowName=2 入金，ExternalTradeNo=cash_exchange_detail.ExternalTradeNo，FundAccount=产品户，SettlementAccount=大账户结算户，AccountBalance=AccountBalance.PreBalance+occurAmount，dealState=0 待处理 
-- #/**账务处理状态 dealState：0-待处理，1-处理中，2-处理成功,3-处理失败，4-已撤销**/
update cashBillOrder set FundAccount=产品户信息，CashInState=4-已调账
-----------------------------------------------------------定时查询(浙商)资金入账 0 0/15 * * * ? end -------------------------------------

-----------------------------------------------------------定时任务调用记账队列 0 0/1 * * * ? start -------------------------------------
SELECT * FROM djjs_fund.accounts_queue t where t.dealState=0;-- 查询数据进行处理，一次处理最大条数由数据库配置
update djjs_fund.accounts_queue set dealState=1 处理中;
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '大账户结算户' for update;  -- 更新大账户结算户余额
-- 更新发生额 ACCOUNT_BALANCE+=occurAmount，USABLE_BALANCE+=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance+#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance+#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- /**acctType 记账类型:1-一般记账,2-冻结记账,3-解冻记账,4-冻结扣划,5-技术调整,
--   * 9-入金记账,10-出金记账,11-日终结算款处理记账,12-反冲记账,13-入金冲正记账,
--   * 14-出金冲正记账,15-转账记账,16-日间结算款处理记账,17-单边账入金调整,18-单边账出金调整,
--   * 19-交易资金划转,20-入金调账记账，25-手工入账调账记账，26-特殊记账，27-单边冻结扣划
--   */
-- 回执状态为成功，更新入金明细状态，并进行记账操作
SELECT * FROM djjs_fund.acct_order acctNo=functionNo=acctType 9，cash_exchange_detail.ExternalTradeNo，AccountOrderStatus=0 0/1/2 待处理/成功/失败，seq获取 AccountOrderNo
-- 记账请求分录表 两条数据，fund_account 两个账号（产品户+大账户结算户）
SELECT * FROM djjs_fund.acct_order_detail t WHERE t.account_order_no = 'AccountOrderNo'; 
-- 生成账务流水，账务余额处理，生成两条账务流水
SELECT * FROM djjs_fund.acct_serial; -- 账务流水表，acct_order.AccountOrderNo，ExternalTradeNo=acct_order.ExternalTradeNo，FundAccount 两个账号（产品户+大账户结算户）
update djjs_fund.accounts_queue set dealState=2;
-----------------------------------------------------------定时任务调用记账队列 0 0/1 * * * ? end -------------------------------------

-- *****************************************************************inford 定时******************************************************************************
-----------------------------------------------------------定时生成付息兑付通知书 0 0 8 * * ? start -----------------------------------
-- #付息兑付计划状态 IntePayStatus 未开始 1，已通知 2，划款中 3，划款成功 4，划款失败 5，已完成 6，延期 7，延期完成 8，失败 9，延期失败 A
-- #付息兑付计划资金反馈结果处理状态  Reserve 等款 0，清算成功 1，清算失败 2，成功 3，失败 4
-- 查询付息兑付计划，供应链，RealPayDate=当前工作日+6并且结果是工作日的日期的数据，IntePayStatus=1，进行处理
-- 修改付息兑付状态
update InterestPayPlanInfo set IntePayBizCode=生成该计划的付息兑付计划业务编号，IntePayBizYear=当前年，IntePayStatus=2，Reserve=0
-- 生成融资人利息及本金资金划转通知书
insert into bill bill.bill_type=54
-- 推送主流程系统融资人利息本金资金划转通知书 C0095052 IScfpService：execReceiveProductAttachments
-----------------------------------------------------------定时生成付息兑付通知书 0 0 8 * * ? end -----------------------------------

-----------------------------------------------------------定时利息拆分 0 0 17 * * ? start -----------------------------------
/**
     * T-2供应链自动利息拆分(T为实际执行日期)，当天=t-2
     * 1、生成付息兑付明细
     * 2、生成付息兑付债权结算指令发送资金结算系统
     * 3、更新付息兑付计划状态为划款中
     * 4、生成利息及本金资金划转明细表
     * */
-- #付款方状态 payStatus pay_status：1-N/A，2-未检查，3-结算中，4-结算完成
-- 查询付息兑付状态为“已通知”+产品类型为“供应链债权融资计划”的记录 IntePayStatus=2，当实际执行日期 RealPayDate-2 的工作日 = 当前日期时，进行利息拆分
-- 按持有投资人进行利息拆分，投资人持有金额（可用+冻结+待付）*本次付息兑付金额（本次划转本金、本次划转利息、本次孳息）/挂牌总额=投资人本次应得利息
-- 生成付息兑付明细 
insert into InfordIntePayCalDetail bondId=ipb.bondId，IntePayId=InterestPayPlanInfo.id，Reserve=IntePayStatus=3，Reserve2=SettleBondFund.ExternalTradeNo，Reserve1=realPayDate（实际支付日期）
-- 生成付息兑付债权结算指令（需要检验投资人借方可用额度是否够用）
insert into SettleBond，PayStatus=2，BizCode=InterestPayPlanInfo.IntePayBizCode，BusiType=4-兑付，CreditAccount=ipb.RecordAccntNo 融资人=收券=贷方，DebitAccount=infordIntePayCalDetail.TrustAccount 投资人=付券=借方，AuditStatus=2，OrderStatus=2，PayChannelId=czb
-- 更新余额 
update InfordAmount，投资人的可用-=发生额，待付+=发生额
-- 流水插入信息记载表 
insert into InfordInformationRecord，同一人的可用到待付
-- 发送资金结算系统 
insert into SettleBondFund SettleBondId=settleBond.id，PayerMemCode='', PayeeMemCode=借方=付券=投资人，新生成 ExternalTradeNo，BusiType=4，FundOpType=4，PayerProductFlag=产品户，PayeeProductFlag=非产品户，OrderStatus=1，SettlementDate=InterestPayPlanInfo.RealPayDate
-- 生成转让划转资金清算指令  
insert into djjs_fund.ChainSettleFund SettleClearStatus=0，NeedAudit=0，EntryForm=0
update SettleBondFund set OrderStatus = 2 划款中
update interestPayPlanInfo set IntePayStatus=3 划款中
-- 生成利息及本金资金划转明细表
insert into bill bill.bill_type=65 利息及本金资金划转明细表

-----------------------------------------------------------定时利息拆分 0 0 17 * * ? end -----------------------------------













