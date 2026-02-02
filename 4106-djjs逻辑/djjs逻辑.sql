-- /********************************************************************系统启动加载缓存数据**********************************/
SELECT * FROM djjs_sys.config_param_info;
SELECT * FROM djjs_sys.dict_main_info;
SELECT * FROM djjs_sys.dict_sub_info;
SELECT * FROM djjs_sys.mapping_dict_sub_info;
SELECT * FROM djjs_sys.error_info;
SELECT * FROM djjs_sys.exchange_info;
SELECT * FROM djjs_sys.function_info;
SELECT * FROM djjs_sys.authority_info;
SELECT * FROM djjs_sys.sys_stage_config;
SELECT * FROM djjs_sys.sub_sys_stage_config;
SELECT * FROM djjs_sys.user_info;

-- **************************************************************对账过程 start*************************************************
-- 导入文件 /home/weblogic/bankExcel/bankProCode/
-- 删除之前导入的文件和数据（如有）
DELETE FROM DJJS_FUND.FUND_D_BANK_FILE_INFO fdbfi WHERE FDBFI .INIT_DATE = '' AND FDBFI .BANK_PRO_CODE = '';
DELETE FROM DJJS_FUND.FUND_D_BANK_TRADE_RESULT fdbtr WHERE FDBTR .INIT_DATE = '' AND FDBTR .BANK_PRO_CODE = '';
-- #文件处理状态 FileDealStatus 1：未处理；2：处理成功；3：处理失败
insert into DJJS_FUND.FUND_D_BANK_FILE_INFO FileDealStatus='2'
insert into djjs_fund.FUND_D_BANK_TRADE_RESULT;-- 导入对账文件 BankFileType=1，FileDealStatus=1，文件保存在 /home/weblogic/bankExcel/ 下
-- 以上为对账文件导入数据信息
-- 对账页面，数据查询sql
SELECT NVL(b.trans_date, '20210531') TRANS_DATE,
           a.task_code TASK_CODE,
           a.task_name TASK_NAME,
           a.bank_pro_code BANK_PRO_CODE,
           b.task_status TASK_STATUS,
            b.memo MEMO
       FROM djjs_fund.fund_d_task_main_def a
       left join (SELECT * FROM djjs_fund.fund_d_task_main_process WHERE trans_date = '20210531') b
         on a.task_code = b.task_code
      WHERE 1=1
       ORDER BY  to_number(a.task_priority) asc;
SELECT * FROM fund_d_task_main_def;-- 日终任务定义主表，固定数据且不变
-- #对账步骤状态枚举 TaskStatus S 已提交，P 正在处理，T 成功，W 警告，F 处理失败
-- ****对账操作
-- 1、设置该主任务为已提交 日终处理日志主表
-- 前置任务校验 父任务是e19的任务，上日的e19任务需要完成，否则当日所有父任务需要完成
merge into fund_d_task_main_process TransDate=当前工作日，TaskCode=taskX，TaskStatus=S
-- 2、异步执行对账，校验数据并变更日终任务状态为处理中 com.cfae.djjs.fund.daily
-- 变更日终任务状态为处理中
update fund_d_task_main_process set TaskStatus=P
-- 主流程处理，1、根据银行产品号获取子任务编号
SELECT a.task_code      TASK_CODE,
		 		a.task_type      TASK_TYPE,
		        a.task_authority TASK_AUTHORITY,
				a.father_task    FATHER_TASK,
				a.exe_type       EXE_TYPE,
				p.status         BANK_PRO_STATUS,
		        b.task_status    TASK_STATUS
		   FROM fund_d_task_def a
      left join fund_bank_product p 
         on (a.bank_pro_code = p.bank_pro_code)
	  left join (SELECT * FROM fund_d_task_process WHERE trans_date = #{transDate} ) b 
	     on (a.task_code = b.task_code)
	      where 1=1 
		  and  a.bank_pro_code = #{bankProCode}
		  order by a.serial_no asc;

SELECT * FROM djjs_fund.fund_d_task_def;-- 日终子任务定义表 
SELECT * FROM djjs_fund.fund_d_task_process;-- 日终子任务处理日志表
-- 主流程处理，2、遍历子任务处理每个子任务节点，前置校验，如果任务属于私有、同时前置任务是e19则判断上一个工作日的e19是否成功，否则校验当日的父任务是否完成；公有则判断该类型的任务其他银行是否已经执行或者正在执行中。
-- ******************************** A、出入金对账预处理
-- 设置子任务为已提交
merge into FUND_D_TASK_PROCESS TransDate=当前工作日，TaskCode=taskX，TaskStatus=S
-- 同步执行子任务对账 1、前置处理(校验数据并变更日终任务状态为处理中)
update FUND_D_TASK_PROCESS set TaskStatus=P
-- 同步执行子任务对账 2、主流程处理 1）、调用存储过程先处理出入金明细表冲正状态与非终态数据：AP_FUND_DAILY_LOCALDATACOMPARE
delete from FUND_D_ERROR_DATA where  trans_date = 当前工作日 and bank_pro_code = '***yqzl' and error_type in ('03','04');
insert into FUND_D_ERROR_DATA
      select S_FUND_D_ERROR_DATA.Nextval,
             null,
             v_bank_no,
             c.pay_channel_type,
             c.init_date,
             '04',
             '资金流水号 =' || c.related_fund_log_id,
             '出入金明细表状态异常！',
             null,
             sysdate
        from cash_exchange_detail c
       where  c.init_date = 当前工作日
         and c.pay_channel_type = '***yqzl'
         and c.cash_flow_status not in('5','6','3');-- 如果有数则报错
-- /**出入金明细状态 cash_flow_status:1-生成记录,2-调用前置失败,3-银行受理中,5-处理成功,6-处理失败,11-记账失败,12-待审核,13-审核通过,14-审核拒绝,15-审核失败-待回执，19-处理中，20-已冲正*/
-- 同步执行子任务对账 2、主流程处理 2）、清除该银行转账类交易明细对帐记录 
delete from  FUND_D_BANK_COMPARE where TRANS_CODE in ('30010100','30020100') and BANK_NO = #{bankNo} and BANK_PRO_CODE = '***yqzl'
-- 调用存储过程 导入的Excel文件解析数据同步到转账交易表 AP_FUND_DAILY_SYNCCOMPARE
-- #compare_flag 对账标志 M-银行多帐 L-资金多账 F-状态不一致 S- 对账成功
insert into fund_d_bank_compare select * from FUND_D_BANK_TRADE_RESULT;-- BANK_COMPARE_TYPE=2, COMPARE_CHECK_STATUS=I I-未处理 S-处理成功
-- 同步执行子任务对账 2、主流程处理 3）、调用存储过程 计算多账，少账、不一致等情况 AP_FUND_DAILY_TRANSSTATISTICS
	/**
	 * 转账明细预处理，主要流程：<br>
     * 1、   清除该银行转账类交易明细对帐记录。
     * 2、  解析银行转账明细文件，将银行数据同步到对帐表中。
     * 3、  与银证流水表核对（只针对对账标志为空，并且交易类型为转帐类交易的记录）。
     *   a)  查找银行对帐表中有，银证流水表中没有的记录（银行多账汇总额和资金清算成功部分部分比对成功则这部分打标 compare_flag=S，否则打标 compare_flag=M），并打标志为M，银行多帐。
     *   b)  查找银证流水表中有（处理成功，冲正的不需要核对），银行对账表中没有的记录（应该没有这样的记录，有就有可疑了），
     *      将银证流水表的记录插入到银行对帐表中，并且打对帐标志为L,交易所多帐。
     *   c)  查找银行对帐表与银证流水表都有记录，但是状态不一致的记录（银证流水为非成功状态），置对帐标志为F，状态不一致。
     *   d)  统计银行对帐表与银证流水表中流水状态一致的条数。
	 */
    --校验银行对账文件数据是否存在非当日数据
    --出入金明细表不存在银行流水号 进行补填  (注：解决前置链接银行，重连接不计入超时时间问题后，这部分更新操作可以去除。T2超时时间按功能号分别设置已实现。)
      --华夏银行出金成功的都没有银行流水号,出入金对账特殊处理 AP_FUND_DAILY_TSTICS_SPECIAL
--状态一致(只校验发送银行的，清算成功或清算失败（不发送银行的的不用校验）)，对账打标 compare_flag=S
--资金结算多帐，直接放到报错信息里 insert into FUND_D_ERROR_DATA 
--银行多账情况，校验清算成功（资金清算成功部分部分）的总金额是否与银行多账部分汇总金额一致，一致则成功，不一致则失败
--其他未标记数据 遍历分类（流水号能对上的数据），1、如果结算数据 cash_exchange_detail cash_flow_status=6-处理失败 ，则算银行多账
-- -- 同步执行子任务对账 3、前置处理后置处理(修改日终处理状态为成功或者失败)
update FUND_D_TASK_PROCESS set TaskStatus=T/F

-- ******************************** B、出入金对账处理
-- 如果存在类型为出入金，对账标志为 M F L ,对账状态为I的 存在对账异常数据，详情查看对账异常！
-- 调用存储过程回写出入金表的对账 AP_FUND_DAILY_SYNCCASHEXDETAIL
update cash_exchange_detail ced set  ced.reconcile_status = '2'
-- ******************************** C、核算余额比对
-- 1、查询资金系统内渠道银行核算账户余额
-- 2、发送银行前置获取核算账户银行端余额
-- 3、校验余额是否一致

-- ******************************** 统计当日汇入和汇出金额
-- 同步执行子任务对账 3、后置处理(修改日终处理状态为成功或者失败)
update fund_d_task_def set TaskStatus=T/F
-- 3、主任务对账后置处理(修改日终处理状态为成功或者失败)
update fund_d_task_main_process set TaskStatus=T/F
-- **************************************************************对账过程 end*************************************************
-- *************************************
/*											结算账号			记账账号			卡号
* cmsbsctyqzl:民生银行(民生银企直连)		Z20181026000003		Z20181026000011		608088800
* citicyqzl:中信银行(中信银行银企直连)		Z20181026000002		Z20181026000010		7111710182600182618
* bocspmyqzl:交通银行(交通银企直连)			Z20181026000004		Z20181026000012		110060149018170100319
* pinganyqzl:平安银行(平安银企直连)			Z20181026000013		Z20181026000015		15000102254872
* hxbnyqzl:华夏银行(华夏银企直连)			Z20181026000016		Z20181026000018		10285000001543430
* chinayqzl:中国银行(中国银行银企直连)		Z20181026000019		Z20181026000021		345470177083
* cebyqzl:光大银行(光大银企直连)			Z20181026000022		Z20181026000024		35000188000651837
* icbcyqzl:工商银行银企(工商银企直连)		Z20181026000025		Z20181026000027		0200004519000100173
* icbcyz:工商银行							Z20181026000001		无
* czb：北金所-浙商银行						Z20181026000028		Z20181026000030		3310008080120100109951
* 浙商测试卡号：3310010000121880106547
* 浙商模拟卡号：3310010010120101598158
*/
-- *************************************
-- *************************************
-- 查询大账户余额数据库配置
SELECT t.*, t.bank_client_no FROM djjs_fund.bind_account t WHERE t.bind_account_type = '1';-- 1:代理结算账户 2:募集资金汇出汇路 3:投资资金汇出汇路 4:安心账号
SELECT * FROM djjs_info.bankaccount; -- 北金所大账户信息获取支付渠道 remark2 如：citicyqzl/hxbnyqzl

/*信息记载接口信息*/
-- *************************************
-- 接口信息
SELECT * FROM djjs_info.systems_message_log t WHERE INSTR(t.request_value,'21CFZR0226')>0;-- 查询三方接口调用失败原因
-- *************************************
-- 1、备案信息推送，merge into reg_notice_info;	C0075001 execTRegNoticeInfo
-- {"requestNo":"e3677b07-20fd-4b39-870a-db4929ee7eea","protocol":"DUBBO","service":"C0075001","version":"1.0","partnerId":"C0027","context":{"regNoticeCode":"BA202101130001","subMemCode":"80000561","trustAccount":"RZ81000270","regNoticeAmount":10,"regNoticeNumber":"债权融资计划[2021] 第0002号","regNoticeStatus":"1","regDateB":1610507928918,"regDateE":1673579928918,"gmtCreate":1610506198000}}
SELECT * FROM djjs_info.reg_notice_info; -- 备案，支持多次修改
-- *************************************
-- 2、产品信息推送，产品码 bond_code，债权码 bond_id	C0075011 execTReceiveProductInfo
-- {"requestNo":"a287be1e-f974-4195-9996-6d3b1f3e19be","protocol":"DUBBO","service":"C0075011","version":"1.0","partnerId":"C0027","context":{"infordProductRights":[],"linkSecondMemberInfo":[{"secondMemCode":"80000567","secondMemName":"债融测试中国银行-北京分行"}],"lzList":[],"fzList":[],"productBasicInstance":{},"infordProductBasic":{"bizId":"210111ZRGP0021","bondFullName":"红红红红2020年度第一期债权融资计划","bondShortName":"21京山东高速ZR019","bondCode":"21CFZR0021","bondScale":101,"regNoticeNumber":"债权融资计划[2020] 第0097号","bookManager":"80000561","bookManagerName":"北京银行-总行","publishModel":"2","bondType":"1","bankNo":"305100000017","bankName":"民生银行","bankAccountNo":"600033045","bankAccountName":"测试2200003220","recordAccntNo":"RZ60001783","fundTransAccntNo":"8110701013101237129","fundTransAccntName":"玉洁企业2","fundTransBankName":"中信银行总行营业部","circulatingGround":"1","financierName":"山东高速集团股份有限公司","leadManagerCode":"80000561","leadManagerName":"北京银行-总行"},"productElementInstance":{},"infordProductElement":{"bondTerm":"2","termUnit":"1","faceValue":100,"valueCurrency":"1","interestMode":"3","irstFrequency":12,"rateType":"2","spreadRate":0,"valueDate":20210112,"maturityDate":20230101,"registrDate":20210112,"irstAssignMode":"2","creditedType":"","isRightsProduct":"2","subFileFlag":"2","leapYearModel":"2","notLeapYearModel":"3","secRatingOrgCode":"","couponRate":5,"publishPriceModel":"1","repayModel":"1","appType":"1"},"productPublishInstance":{},"infordProductPublish":{"infordOfferedType":"1","publishDateB":20210112,"publishDateE":20210112,"noticeDate":20210113,"consignPayEndDate":20210112,"firstPayDate":20220101},"stageRepayInfoInstance":{},"infordStageRepayInfo":[{"repayDate":20230101,"repayCorpus":101.00,"hundredRemainingCorpus":0.00,"repayCorpusTotal":101,"repayPercent":100.00}],"productRightsInstance":{}}}
SELECT * FROM djjs_info.inford_product_basic; -- 产品基本信息 financier_code 信息记载账号
SELECT * FROM djjs_info.inford_product_element; -- 产品要素
SELECT t.second_mem_code as inford_product_basic.financier_code FROM djjs_info.account_role t WHERE t.trust_account = '融资人信息记载账号（接口传递）';
SELECT * FROM djjs_info.inford_product_publish; -- 产品挂牌信息记载表
SELECT * FROM djjs_info.inford_stage_repay_info; -- 信息记载分期偿还本金信息表 list
SELECT * FROM djjs_info.inford_product_rights; -- 含权信息 list
SELECT * FROM djjs_info.inford_product_manager; -- 联主/副主 list

SELECT * FROM djjs_info.interest_pay_plan_info t WHERE t.bond_id = '201907040755' ORDER BY t.inte_pay_date;-- 付息兑付计划
SELECT * FROM djjs_info.inford_product_survival t WHERE t.bond_id = '201907040755';-- 存续期信息
-- *************************************

-- *************************************
-- 3、定价配售 C0075012 execTReceivePlacingInfo，有多次校验，产品码bond_code查产品，查定价配售表信息；一二号系统用，传投资人的参与人账号和信息记载账号，产品表的融资人账号查付券方参与人账号
-- 定价配售
-- {"requestNo":"3a27b090-44cc-4868-b802-b83268cff2e1","protocol":"DUBBO","service":"C0075012","version":"1.0","partnerId":"C0027","context":{"bondCode":"21CFZR0027","bondFullName":"merrychristmas2020年度第一期债权融资计划","bondShortName":"21京恒大地产ZR004","biddingRate":5,"planPublishAmount":300,"settleType":"1","appType":"1","list":[{"secondMemCode":"80000561","secondMemName":"北京银行-总行","trustAccount":"TZ80000561","trustAccountName":"北京银行-总行","fundTransAmount":300,"bankNo":"15000100714914"}],"pricingDtailInfoInstance":{}}}
insert into djjs_info.placing_result bondId; 
insert into djjs_info.placing_detail BatchId=placing_result.id; -- 配售详情 list，结算模式由详情中的二级参与人确定
select * from djjs_info.second_member where mem_code = ''; -- 结算模式 placing_detail.BankNo=second_member.SecurityAccount 时，则为安心模式，否则为场内
-- 生成付息兑付计划，相关信息获取在 InfordProductElement 中，供应链产品资金划付日为之前的实际付款日期加一个工作日，删除未开始的数据
insert into djjs_info.interest_pay_plan_info; -- 贴现式+零息式，一条数据，到期一次还本；付息固定式+浮息+利随本清式：list；付息兑付计划
-- 生成附件
SELECT * FROM djjs_info.bill t WHERE t.bond_id = '' AND t.bill_type = '56';
/** 附件类型 bill_type
  * 52/信息记载确认单 54/融资人利息/本金资金划转通知书 55/融资人利息/本金资金划转成功通知书 56/场外场内新增产品接收时生成：产品付息兑付计划 57/融资人到账确认通知书
  * 58/修改产品凭证 59/原始产品上市付息兑付计划表 60/挂牌缴款单 61/转让缴款单 62/修改付息兑付计划附件 63/修改产品临时凭证 64/修改付息兑付计划附件临时凭证
** 65/利息及本金资金划转明细表 66/定价配售结果确认单 67/转让成交单 68/银行流水入账回单 69/产品户开户回单 70/产品户销户回单 71/银行流水出帐回单 
** 72/分销第一阶段文件 73/分销第二阶段文件
*/
-- 根据详情生成债权结算指令信息
insert into djjs_info.settle_bond BizCode=ipb.BizId 业务编码，DealDate=productElement.RegistrDate，CreditAccount=placing_detail.TrustAccount 收券投资人账户贷方 信息记载账号，CreditMemCode=secondMemCode 参与人账号，DebitAccount=ipb.RecordAccntNo 付券融资人账户借方 信息记载账号，DebitMemCode=ipb.RecordAccntNo 查询 AccountRole表 参与人账号，busi_Type=1 挂牌，order_status=2 处理中，auditStatus=2 复核通过，SettleType=结算模式（场内/场外） 如果是场内，则查渠道行，根据融资资金账号（大账号） ipb.FundTransAccntNo 查询，pay_status=2 未检查; 
SELECT *, remark2 FROM djjs_info.bankaccount t WHERE t.bank_account_no = 'FundTransAccntNo';-- 在视图中查询
-- #结算指令状态 orderStatus：1-未生效，2-处理中，3-处理成功，4-处理失败，5-已撤销，6-冻款成功，7-划款失败，8-解冻成功，9-解冻失败
-- #付款方状态 payStatus pay_status：1-N/A，2-未检查，3-结算中，4-结算完成
-- *************************************
-- 4、转让 C0075024
-- {"requestNo":"35023f30-fb2d-4815-9b15-d717b47f5099","protocol":"DUBBO","service":"C0075024","version":"1.0","partnerId":"C0027","context":{"bizCode":"ZSRYX202101200019","busiType":"2","bondCode":"21CFZR0027","bondShortName":"21京恒大地产ZR004","tradeAmount":0.01,"settlementAmount":1,"initDate":1611072000000,"dealDate":1611158400000,"creditSecondMemCode":"80000568","debitSecondMemCode":"80000565","creditAccountBankName":"债融测试投资人机构-天津","debitAccountBankName":"债融测试投资人机构-河北","creditBankName":"中国工商银行股份有限公司北京金融街支行营业室","debitBankName":"中国工商银行股份有限公司北京金融街支行营业室","creditAccountBankNo":"AX202012300001","debitAccountBankNo":"AX202012300004","creditLargeBankNo":"102100021684","debitLargeBankNo":"102100021684","creditAccount":"TZ80000561","debitAccount":"TZ80000561","settleType":"3"}}
SELECT * FROM djjs_info.settle_bond t WHERE t.biz_code = ''; -- 主流程传 bizCode 业务编号；busiType=2转让，order_status=2处理中，auditStatus=2复核通过，pay_status=2未检查
SELECT * FROM djjs_info.inford_amount t WHERE t.bond_id = '' AND t.record_accnt_no = ''; -- 更新实时持仓信息
SELECT * FROM djjs_info.inford_information_record t; -- 记录信息记载流水，金额/账簿变动记录
-- *************************************
----------------------------------------- inford 定时：债券清算任务 0 0/1 * * * ? start-------------------------------------------------------
-- ******************************债券结算指令处理 start
-- A、挂牌业务1位投资者-场内
SELECT * FROM djjs_info.settle_bond t WHERE t.settle_type = '1 场内' AND t.pay_status = '2' AND t.order_status = '2' AND t.busi_type = '1 挂牌';
-- # 1 是,2 否
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者 参与人账号，PayeeMemCode=ipb.BookManager 收款方主承销商 参与人账号，PayeeBankAcctName=ipb.BankAccountName 收款方银行账户名，PayeeBankAccount=ipb.BankAccountNo 收款方银行卡号，IsPayerSecu=2 否 付款方非安心，IsNeedConfirm=2 否，IsMain=1 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，新生成 ExternalTradeNo
update settle_bond set pay_status=3 结算中
-- B、挂牌业务多位投资者-场内
-- #收款账户类型 ReceAccountType：1：资金账户 2：安心账户 3：汇出汇路 4：普通银行账户
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者，PayeeMemCode=ipb.BookManager 收款方主承销商，ReceAccountType=1 收款方类型 资金账户，IsPayerSecu=2 否 付款方非安心，IsNeedConfirm=2 否，IsMain=2 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，新生成 ExternalTradeNo
update settle_bond set pay_status=3 结算中
-- 付款确认信息map key 承销商编号|bondId|bondCode，value 资金账号_业务编号_结算日期_债券简称_收款银行账户名称_银行账户_开户行名称_大额行号_挂牌资金
-- 挂牌业务北金所模式，多个投资者，生成出款指令
insert into djjs_info.settle_bond_fund t PayerMemCode=承销商编号，PayeeMemCode=承销商编号，IsNeedConfirm=1 是，IsPayerSecu=2 否，PayeeBank***=收款方信息 map是的values，渠道行由 map中的 value 资金账号 确认，IsMain=1 是，新生成 ExternalTradeNo
-- C、挂牌：1位投资者，安心模式
SELECT * FROM djjs_info.settle_bond t WHERE t.settle_type = '3 安心' AND t.pay_status = '2' AND t.order_status = '2' AND t.busi_type = '1 挂牌';
-- 检验主承的募集资金汇出汇路不能为空
-- if  主承销商和投资者（收款方）是一个人的时候，不需要生成付款方到主承销商的资金划款指令
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者，PayeeMemCode=ipb.BookManager 收款方主承销商，ReceAccountType=2 收款方类型 安心账户，IsPayerSecu=1 是 付款方是安心，IsNeedConfirm=2 否，IsMain=2 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，新生成 ExternalTradeNo
update settle_bond set pay_status=3 结算中
insert into djjs_info.settle_bond_fund t PayerMemCode=承销商编号，PayeeMemCode=承销商编号，IsNeedConfirm=2 否，IsPayerSecu=1 是，PayeeBank***=检验是查询的收款方信息，无渠道行信息，IsMain=2 否，新生成 ExternalTradeNo
-- else 
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=承销商编号，PayeeMemCode=承销商编号，IsNeedConfirm=2 否，IsPayerSecu=1 是，PayeeBank***=检验是查询的收款方信息，无渠道行信息，IsMain=2 否，新生成 ExternalTradeNo
-- D、挂牌：多位投资者，安心模式
-- if  主承销商和投资者（收款方）是一个人的时候，不需要生成付款方到主承销商的资金划款指令
-- else
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者，PayeeMemCode=ipb.BookManager 收款方主承销商，ReceAccountType=2 收款方类型 安心账户，IsPayerSecu=1 是 付款方是安心，IsNeedConfirm=2 否，IsMain=2 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，新生成 ExternalTradeNo
update settle_bond set pay_status=3 结算中
-- 付款确认信息map key 承销商编号|bondId|bondCode，value 资金账号_业务编号_结算日期_债券简称_收款银行账户名称_银行账户_开户行名称_大额行号_挂牌资金
-- 检验主承的募集资金汇出汇路不能为空
insert into djjs_info.settle_bond_fund t PayerMemCode=承销商编号，PayeeMemCode=承销商编号，IsNeedConfirm=2 否，IsPayerSecu 1 是安心，PayeeBank***=收款方信息 map是的values，无渠道行，IsMain=1 是，新生成 ExternalTradeNo
-- E、挂牌：北金所与安心账户结合模式
-- if 安心账户模式，并且付款方和收款方为同一人 sb.CreditMemCode=ipb.BookManager && sb.SettleType=3 安心模式，不生成指令信息
-- else 
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者，PayeeMemCode=ipb.BookManager 收款方主承销商，ReceAccountType=2 收款方类型 安心账户，IsNeedConfirm=2 否，IsMain=2 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，if sb.settleType=1 场内，IsPayerSecu=2 否 付款方非安心，PayChannelId=渠道行；else IsPayerSecu=1 是 付款方安心，新生成 ExternalTradeNo
update settle_bond set pay_status=3 结算中
-- 付款确认信息map key 承销商编号|bondId|bondCode，value 资金账号_业务编号_结算日期_债券简称_收款银行账户名称_银行账户_开户行名称_大额行号_挂牌资金
-- 检验主承的募集资金汇出汇路不能为空
insert into djjs_info.settle_bond_fund t PayerMemCode=承销商编号，PayeeMemCode=承销商编号，IsNeedConfirm=2 否，IsPayerSecu 1 是安心，PayeeBank***=收款方信息 map是的values，无渠道行，IsMain=1 是，新生成 ExternalTradeNo
-- F、转让和兑付
SELECT * FROM djjs_info.settle_bond t WHERE t.settle_type in ('1场内，3安心') AND t.pay_status = '2' AND t.order_status = '2' AND t.busi_type in ('2转让，4兑付');
-- 通过付息兑付利息拆分的指令不处理
-- 兑付（付款方为大账户，非安心）
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者，PayeeMemCode=sb.DebitMemCode 收款方投资人，BusiType=7 兑付，PayChannelId=产品表结算行数据查询，if sb.settleType=1 场内，PayeeBank***=收款方-付券-借方账号查询，else ReceAccountType=2 收款方类型 安心账户。IsPayerSecu=2 否 付款方非安心，IsNeedConfirm=2 否，IsMain=2 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，新生成 ExternalTradeNo
-- 转让
insert into djjs_info.settle_bond_fund t SettleBondId=sb.Id，PayerMemCode=sb.CreditMemCode 付款方投资者，PayeeMemCode=sb.DebitMemCode 收款方投资人，BusiType=2 转让，if sb.settleType=1 场内，PayChannelId=sb.PayChannelId，PayeeBank***=收款方-转让方-借方账号查询，else IsPayerSecu=1 是 付款方是安心，ReceAccountType=2 收款方类型 安心账户。IsNeedConfirm=2 否，IsMain=2 是否是挂牌主承出款后，更改结算状态，OrderStatus=1 待处理，新生成 ExternalTradeNo
update settle_bond set pay_status=3 结算中
-- ******************************债券结算指令处理 end
select * from djjs_info.settle_bond_fund t where t.OrderStatus=1 and t.settleFundId is null and t.errorNo is null;
-- djjs_info.settle_bond_fund 查询结果批处理
-- 与资金子系统交互存日志
insert into report_log TransDate=new Date(), MsgTitle = '资金划转新增操作接口';
-- 挂牌才会有银行账户信息，非挂牌业务不会传递银行账户信息
-- A、场内一个投资人挂牌，付款方信息为空，收款方用银行账号
-- 用产品信息中的收款方信息查 完整的收款方汇出汇路，如果查不到时从常用银行信息中查询，再没有就在里面新增 ReceAccountType=4 常用银行账户
SELECT * FROM djjs_fund.bind_account t WHERE t.mem_code = 'payeeMemCode' AND t.bank_account = '收款方银行账号' AND t.bank_account_name = '账户名称'; -- ReceAccountType=3 汇出汇路
SELECT * FROM djjs_fund.common_bank_info t WHERE t.bank_account = ''; -- ReceAccountType=4 普通银行账户
-- 查询付款方是否有资金账户
SELECT * FROM djjs_fund.fund_account t WHERE t.mem_code = 'PayerMemCode 付款方投资者 参与人账号';-- 检验，查询必须有值 结果为 payerFundAccount=payerFundAccount.FundAccount，Reserve2=payerFundAccount.AccountName, ImExportType=汇入(1)/汇出(2) 用于插入 settle_fund 数据
-- if djjs_info.settle_bond_fund.IsNeedConfirm=1，则 SettDealStatus=2 付款未确认；else if 付款方是安心账户，则 settDealStatus=3 付款已确认，PayChannelId=icbcyz；else settDealStatus=1 待核销
-- 新增划转指令信息表信息
insert into djjs_fund.settle_fund 生成主键id，付款信息和收款信息与 settle_bond_fund 一致，生成 SettleFundId，并且查询并插入付款方的 投资人结算账户信息 payerFundAccount 和收款方的 payeeBank*** 主承汇出汇路 ReceAccountType=3/4, payerFundAccount=payerFundAccount.FundAccount，Reserve2=payerFundAccount.AccountName, ImExportType=汇入(1)/汇出(2), SettDealStatus=1 待核销
-- #SettDealStatus 划转指令处理状态 0：未生效，1：待核销，2：付款未确认，3：付款已确认，4：已推送结算，5：处理成功，6：处理失败，7：已撤销，8：清算成功，9：清算失败
update settle_bond_fund set orderStatus=2 处理中
-- 处理待确认数据
select * from djjs_info.settle_bond_fund t where t.settleFundId is not null and t.IsNeedConfirm=1 and t.ConfirmState is null;
-- settleFundId+PayChannelId ，符合条件，settleFundId查询 settle_fund 数据 SettDealStatus=2，则进行以下操作
update djjs_fund.settle_fund set SettDealStatus=3 付款已确认
update djjs_info.settle_bond_fund t set t.ConfirmState=1 已经付款确认成功

----------------------------------------- inford 定时：债券清算任务 0 0/1 * * * ? end-------------------------------------------------------
-- *************************************
------------------------------------------------- inford 定时：日终数据归历史 start 0 30 23 * * ?
insert into djjs_info.his_inford_amount SELECT * FROM djjs_info.inford_amount b where b.init_date = 'djjs_sys.calendar_main_info.current_workday当天';
------------------------------------------------- inford 定时：日终数据归历史 end 0 30 23 * * ?
------------------------------------------------- inford 定时：日初数据归历史 start 0 30 0 * * ?
-- 查询上一交易日是否已归档，没有归档进行归档
insert into djjs_info.his_inford_amount SELECT * FROM djjs_info.inford_amount b where b.init_date = 'djjs_sys.calendar_main_info.current_workday-1天';
------------------------------------------------- inford 定时：日初数据归历史 end 0 30 0 * * ?

------------------------------------------------- inford 定时：更新信息记载账户信息 start 0 0/3 * * * ?
-- 更新日志记在 sys_log
-- #ExecState OperResult 执行状态 未执行-0, 执行中-1, 执行成功-2, 执行失败-3
-- #SysOpType 系统操作类型 S1 定时任务一级参与人变更, S2 定时任务二级参与人变更, S3 定时任务参与人角色变更
/*查询 ods_member 表未执行或执行失败次数少于3次的数据更新member表*/
-- ods_member if MemCode=null时，update ods_member set ExecMsg='会员编号不能为空', ExecState='3' 执行失败, ExecCount+=1
insert into sys_log OperResult='3 执行失败', SysOpType='S1';
merge into Member;
update ods_member set ExecState='2 执行成功', ExecCount+=1;
insert into sys_log OperResult='2 执行成功', SysOpType='S1';

/*查询ods_second_member表未执行或执行失败次数少于3次的数据更新second_member表*/
-- ods_second_member if MemCode=null || SecondMemCode=null 时，update ods_second_member set ExecMsg='会员编号 || 二级参与人代码 不能为空', ExecState='3' 执行失败, ExecCount+=1
insert into sys_log OperResult='3 执行失败', SysOpType='S2';
merge into second_member;
update ods_second_member set ExecState='2 执行成功', ExecCount+=1;
insert into sys_log OperResult='2 执行成功', SysOpType='S2';

/*查询ods_account_role表未执行的数据更新account_role表*/
-- ods_account_role if MemCode=null || SecondMemCode=null || 使用 MemCode 查询 member表，使用 SecondMemCode 查询 second_member表为空 || TrustAccountName=null || RoleType=null || TrustAccountStatus=null 时，update ods_account_role set ExecMsg='会员编号 || 二级参与人代码 || 托管账户名 || 角色类型 || 托管账户状态 不能为空', ExecState='3' 执行失败, ExecCount+=1
insert into sys_log OperResult='3 执行失败', SysOpType='S3';
merge into account_role;
update ods_account_role set ExecState='2 执行成功', ExecCount+=1;
insert into sys_log OperResult='2 执行成功', SysOpType='S3';
-- #RoleType 业务角色 0-北金所 1-主承 2-联主 3-挂牌管理人 4-团成员 5-投资人 6-融资人 7-代理发起人
-- RoleType=1 主承获取募集资金汇出汇路 AccountRole.BankClob set RaiseAccountName='ca_username', RaiseAccountBankNo='ca_account', RaiseOpenBankName='ca_bankName', RaiseLargeBankNo='ca_linenum'
-- RoleType=5 投资人获取信息记载账号以及投资资金汇出汇路 AccountRole.TrustAccountClob set TrustAccount='tz_ir_account'; AccountRole.BankClob set InvestorAccountBankName='tz_username', InvestorAccountBankNo='tz_account', InvestorOpenBankName='tz_bankName', InvestorLargeBankNo='tz_linenum', Reserve1='tz_zs_account_name', Reserve2='tz_zs_account', Reserve3='tz_zs_open_bank_name', Reserve4='tz_zs_large_bank_no'
-- RoleType=6 融资人获取信息记载账号 AccountRole.TrustAccountClob set TrustAccount='tz_ir_account', Reserve5='rz_role'
SELECT * FROM DJJS_INFO.ACCOUNT_ROLE ar where ar.second_mem_code = '' and ar.role_type = ''; -- 确认新增/修改
/****************************新增账户信息 start**********************************/
insert into DJJS_INFO.ACCOUNT_ROLE id=存储过程生成 2218, accountRole;
insert into DJJS_INFO.trustAccountH;
-- 资金入参 fundAccount.MemCode=AccountRole.SecondMemCode, InfoRecordAccount=AccountRole.TrustAccount, AccountName=AccountRole.TrustAccountName, InfordAccountStatus=AccountRole.TrustAccountStatus
-- 推送参与人信息到资金结算系统
-- 新增结算账户
insert into report_log set RequestArgs=fundAccount.json, MsgTitle='参与人资金账户操作接口';
-- #SubjectCode 科目代码 0-工商 100010000, 1-中信 100020000, 2-民生 100030000, 3-交通 100040000, 4-外部 安心 200010000, 5-外部 非安心 200020000, 6-内部专用 200030000, 7-外部账户-供应链 200040000
-- #AccntFlag 核算标识:1-是,2-否
-- #AccountType 资金账户类型:1-内部账户,2-外部账户,2-浙商
-- #BalanceDirection 资金余额方向:1-借方,2-贷方
-- #FundAccountStatus 资金账号状态:0-未生效,1-已生效,2-已停用,3-待停用,4-待启用 5-冻结 6-注销
insert into djjs_fund.fundAccount MemCode=AccountRole.SecondMemCode, InfoRecordAccount=AccountRole.TrustAccount, AccountName=AccountRole.TrustAccountName, InfordAccountStatus=AccountRole.TrustAccountStatus, Currency='CNY', SubjectCode='200020000', AccntFlag='2', AccountType='2', BalanceDirection='2', FundAccountStatus='1', IsSecurityAccount='2 非安心', EntryForm='0 接口录入', fundAccount='fundAccountNo 存储过程生成再用java处理';
insert into AccountBalance 拷贝 fundAccount 属性, AccntType=fundAccount.AccountType 账户类型;
-- 修改结算账户
-- 账户名没变直接返回
update djjs_fund.fundAccount set MemCode, InfoRecordAccount, FundAccountStatus, AccountName, IdNo, IdKind where fundAccount='fundAccountNo';
update djjs_fund.ACCOUNT_BALANCE set MemCode, AccountName where fundAccount='fundAccountNo';
-- 新增资金银行账户
-- if RoleType=1 && AccountRole.Raise*** is not null
-- 推送主承募集资金汇出汇路到资金结算系统
-- #MemRoles 参与人角色  1-北金所 2-主承销商 3-投资者 4-主承-投资者
-- #BindAccountType 绑卡账户类型 1-代理结算账户 2-募集资金汇出汇路 3-投资资金汇出汇路 4-安心账号
-- 条件 bindAccount->MemCode=SecondMemCode, MemRoles=2, BindAccountType=2, AccountName=TrustAccountName, InfoRecordAccount=TrustAccount, BankAccountName=RaiseAccountName, BankAccount=RaiseAccountBankNo, MemOpenBankNo=RaiseLargeBankNo, BankName=RaiseOpenBankName, InfordAccountStatus=TrustAccountStatus
insert into report_log set RequestArgs=fundAccount.json, MsgTitle='参与人会员银行账户操作接口';
-- 推送投资人汇出汇路到资金结算系统
-- if RoleType=5
-- 条件 bindAccount->MemCode=SecondMemCode, MemRoles=3, BindAccountType=3, AccountName=TrustAccountName, InfoRecordAccount=TrustAccount, BankAccountName=InvestorAccountBankName, BankAccount=InvestorAccountBankNo, MemOpenBankNo=InvestorLargeBankNo, BankName=InvestorOpenBankName, InfordAccountStatus=TrustAccountStatus
insert into report_log set RequestArgs=fundAccount.json, MsgTitle='参与人会员银行账户操作接口';
-- if bindAccount.Reserve2 is not null 
-- 推浙商供应链投资人结算账户信息到资金结算系统
-- 条件 bindAccount->MemCode=SecondMemCode, AccountName=TrustAccountName, InfoRecordAccount=TrustAccount, PayChannelId='czb', InfordAccountStatus=TrustAccountStatus, BankClientNo=Reserve2, BankClientName=Reserve1
insert into report_log set RequestArgs=fundAccount.json, MsgTitle='供应链参与人账户操作接口';

/****************************新增账户信息 end **********************************/
/****************************修改账户信息 start**********************************/
-- if 信息记载账户名称有变化，更新所有产品的信息记载账户名称
update InfordProductBasic set FinancierName='AccountRole.TrustAccountName' where RecordAccntNo='AccountRole.TrustAccount' and FinancierName='oldAccountRole.TrustAccountName';
update DJJS_INFO.ACCOUNT_ROLE accountRole where id='';
insert into DJJS_INFO.trustAccountH;
/****************************修改账户信息 end **********************************/


-- ods_member-->member；ods_second_member-->second_member；ods_account_role-->account_role；新增trust_account_h；新增fund_account；新增account_balance；新增bind_account；
------------------------------------------------- inford 定时：更新信息记载账户信息 end 0 0/3 * * * ?


/*资金结算*/
--------------------------------------------------------------- fund 定时任务-工作日历和工商银行支付渠道日切		0 0 0 * * ? start---------------------------
-- 1、工作日历日切
update djjs_sys.CALENDAR_MAIN_INFO t set t.current_workday = '下一个工作日';
-- 调用存储过程 djjs_fund.AP_PAY_WAY_DAY_CUT 工商日切
update djjs_fund.pay_way t set t.init_date='下一个工作日', t.update_date=to_number(to_char(sysdate, 'yyyymmdd')),
                t.update_time=to_number(to_char(sysdate, 'hh24miss'))
                where t.exchange_id='0000000' and t.init_date='当前工作日' and t.pay_channel_id='icbcyz';
-- 2、核算余额和安心账户余额存入每日余额表，调用存储过程 djjs_fund.AP_DAY_ACCOUNT_BALANCE
insert into djjs_fund.ay_account_balance
select '前一个自然日',t.fund_account,t.mem_code,t.account_name,
			  t.accnt_type,t.currency,t.subject_code,'2' is_security_account,'1' accnt_flag,
			  t.balance_direction,t.begin_account_balance,
			  t.account_balance,t.freeze_balance,t.usable_balance,t.fetch_balance,
			  (select to_number(to_char(sysdate,'yyyymmdd')) from dual),
			  (select to_number(to_char(sysdate,'hh24miss')) from dual) update_time,t.md5_result,f.pay_channel_id
		    from djjs_fund.account_balance t,djjs_fund.fund_account f
		    where t.accnt_type ='1'
		     and t.balance_direction='1'
		     and f.accnt_flag ='1'
		     and t.fund_account = f.fund_account
		   union all
		   select '前一个自然日',t.fund_account,t.mem_code,t.account_name,
			  t.accnt_type,t.currency,t.subject_code,'1' is_security_account,'2' accnt_flag,
			  t.balance_direction,t.begin_account_balance,
			  t.account_balance,t.freeze_balance,t.usable_balance,t.fetch_balance,
			  (select to_number(to_char(sysdate,'yyyymmdd')) from dual) update_date,
			  (select to_number(to_char(sysdate,'hh24miss')) from dual) update_time,t.md5_result,f.pay_channel_id
		   from djjs_fund.account_balance t,djjs_fund.fund_account f
			where t.fund_account = f.fund_account
			and (f.is_security_account ='1' or f.account_type='3');
-- 3、其他支付渠道日历变更
update djjs_fund.pay_way t set t.init_date='当前自然日', t.update_date=to_number(to_char(sysdate, 'yyyymmdd')),
                t.update_time=to_number(to_char(sysdate, 'hh24miss'))
                where t.exchange_id='0000000' and (t.pay_channel_id='citicyqzl'or t.pay_channel_id='cmsbsctyqzl' or t.pay_channel_id='bocspmyqzl');

--------------------------------------------------------------- fund 定时任务-工作日历和工商银行支付渠道日切		0 0 0 * * ? end---------------------------

--------------------------------------------------------------- fund 查询银行流水，处理入金流水 0 0/15 * * * ? start ---------------------------
-- 定时，查询各家银行入金明细，入参BankProCode=payChannelId+bankNo=301A+TransCode=90030015
SELECT * FROM djjs_sys.calendar_main_info; -- 当前工作日 WorkDate
SELECT * FROM djjs_fund.pay_way; -- 支付渠道payChannelId->大账户结算账号 SETTLEMENT_ACCOUNT Z20181026000016
SELECT * FROM djjs_fund.pay_channel_config; -- 支付渠道->开户行行号 BANK_NO 304A
SELECT * FROM djjs_fund.bind_account WHERE fund_account = 'Z20181026000016'; -- fund_account=SETTLEMENT_ACCOUNT->绑卡信息 BANK_ACCOUNT 用于查询流水;
-- 以上信息封装查询入金流水请求参数，TransCode=90030015，SettleBankAccount=大账户账号，BANK_NO，BankProCode=渠道行，生成新的流水号 BizNo
/* 银行出入金时添加银证流水
   1、定时先发送银行查询流水请求（入金）
   出入参数落库 djjs_sys.report_log 表
*/
-- #TransStatus 请求状态:0-未报,1-已报,2-成功,3-失败,4-待撤,5-撤销,7-待冲正,8-已冲正,9-处理中
-- getMessage()生成银行流水，发起查询记录，前置组装请求报文时会生成并落库
insert into djjs_fund.fund_bank_transfer FundBankTransfer BankProCode=渠道编号，TransStatus=0，RepeatTimes=0，FundBillNo=Request.BizNo 查询流水封装数据时新生成 BankTransRequest，InnerBillNo=yy+90030015+6位seq，transType=90030015
insert into djjs_sys.report_log MsgTitle='**银行银企直连+code', BankProCode='****yqzl', BankBillNo='银行返回流水号'; -- 调用银企直联记录
-- #cashInstate=0/1/2/3/4/5/6	未入账/入账中/待调账/调账中/已调账/已核销/已退回
-- #mergeFlag=0/1/2/3 未合并/合并中/被合并/合并
-- 根据查询出入金记录生成流水新增来账指令数据，记录付款方(投资人)账户信息
insert into djjs_fund.cash_bill_order cashBillOrder PayChannelId=渠道行，BankBillNo=银行流水号，TransDate+TransTime=交易时间，pay***=付款方信息，OccurAmount=发生额单位 分，Remark=Postscript+"|"+Remark，auditStatus=1 待审核，cashInstate=0 未入账，mergeFlag=0 未合并
-- 批量发送资金系统，资金系统异步处理
-- for循环 
-- 查询账户信息 start
-- 1、根据银行产品代码和reser1获取待确认资金账户（记账账户）
SELECT * FROM djjs_fund.fund_account WHERE pay_channel_id = '' and reserve1 = '1'; -- 大账户入账待确认资金账户 FUND_ACCOUNT Z20181026000012 记账
-- 查询账户信息 end
-- 2、入账账户校验(待入账账户)，查询 fundAccount（大账户记账账户 Z20181026000012）+payWay（大账户核算账户 Z20181026000004）+BindAccount（卡号）
-- 查全部银行大账户核算账户，FUND_ACCOUNT Z20181026000004 核算，用于校验是否跨行调拨
SELECT * FROM djjs_fund.fund_account WHERE accnt_flag = '1';
select  b.bank_account from djjs_fund.fund_account f,djjs_fund.bind_account b -- 使用核算账户查询卡信息对应的银行账号列表，用于以下校验
		 where f.accnt_flag='1' -- 核算标识：是
		 and f.fund_account = b.fund_account;
---------------------------------------------------------------- 如果付款方 cashBillOrder.PaycardNo 是大账户核算账户的几个银行卡号，但不是本渠道的银行则为跨行调拨，已合并，备注信息"跨行调拨默认成功"；
update cashBillOrder set CashInState=4 已调账，mergeFlag=3 合并，Reserve4=跨行调拨来账默认成功！，UnRevocationAmount=发生额 未核销金额
continue;-- 执行下一个来账指令处理
---------------------------------------------------------------- 否则 3、入账到资金待确认账户或存在结算款的资金账户内 start
-- 执行入账的账务处理
-- cashBillOrder+fundAccount（大账户记账账户 Z20181026000012）+payWay（大账户核算账户 Z20181026000004）+BindAccount（卡号）
-- 付款方为 cashBillOrder 中的投资人支付卡信息，收款方为 BindAccount 大账户的卡信息
-- #SourceFrom /**交易来源:1-银行端,2-交易所端,3-清算中心,14-日终银行端,24-日终交易所端*/
-- 新增一条出入金明细
insert into djjs_fund.cash_exchange_detail fundAccount=大账户记账账户，ExternalTradeNo 生成新的，BankBillNo=cashBillOrder.BankBillNo 银行流水号，SourceFrom=1 银行端，CashFlowName=2 入金，Pay***=银行返回付款方信息，Recei***=收款方信息 结算大账户的卡信息，ReconcileStatus=1 未对账，CASH_FLOW_STATUS=5 处理成功
-- #CashFlowName /**出入金标识:1-出金,2-入金,3-出金申请,4-出金冲正,5-入金冲正,6-结算,7-结算冲正*/
-- #/**ReconcileStatus 出入金明细对账状态:1-未对账,2-对账成功,3-对账失败*/
-- #/**出入金明细状态 CASH_FLOW_STATUS:1-生成记录,2-超时,5-处理成功,6-处理失败,11-记账失败（出入金时，调用前置成功，余额更新成功、出入金明细成功，但记账失败）,12-待审核,13-审核通过,14-审核拒绝,15-审核失败-待回执，19-处理中，20-已冲正*/
-- 更新余额(大账户记账账户) AccountBalance，入金加钱
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = 'Z20181026000012' for update; 
-- 更新发生额 ACCOUNT_BALANCE+=occurAmount，USABLE_BALANCE+=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance+#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance+#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 返回值：AccountBalance.PreBalance=account_balance.AccountBalance, AccountBalance.AccountBalance=account_balance.AccountBalance+occurAmount(发生额)

-- 进行核算记账账户记账操作，accounts_queue 中的金额和上面更新后的 account_balance 余额信息是一样的
-- 新增入账队列一条
insert into djjs_fund.accounts_queue CashFlowName=2 入金，DealState=0 待处理，ExternalTradeNo=cash_exchange_detail.ExternalTradeNo，FundAccount=大账户记账账户，SettlementAccount=大账户核算账户，SourceFrom=1 银行端入金
-- /**账务处理状态 dealState：0-待处理，1-处理中，2-处理成功,3-处理失败，4-已撤销**/
---------------------------------------------------------------- 否则 3、入账到资金待确认账户或存在结算款的资金账户内 end
-- 4、更新来账指令的资金账户为待确认资金账户,入账状态”待调账“
update cash_bill_order cashBillOrder set cashInstate=2 待调账，waitFundAccount=Z20181026000012 大账户记账账户，UnRevocationAmount=cashBillOrder.OccurAmount 待调账金额
-- ***********************************************自动调账，入金的本金流水有付款银行账户名称，利息无付款银行账户名称，（非安心账户入账到待确认中间户后，手工调账调到用户的资金账户里）
-- 5、根据流水中“付款银行账户名称” cash_bill_order.PaycardName 如果非空，查询资金账户中资金账户名称一致并唯一且状态正常的参与人，投资人账户
-- 付款方名称和结算账户名称（参与人系统录入同步的参与人名称，非银行账户名称）匹配
SELECT * FROM djjs_fund.fund_account t WHERE t.account_name = 'PaycardName'; -- 用于调账
-- 调账入参：CashBillSerialNo=cashBillOrder.CashBillSerialNo，OppFundAccount=fund_account.FundAccount 投资人账户
-- *******************************数据校验 start
-- 检验1、cashBillOrder.CashBillSerialNo 查 cashBillOrder.CashInState != 2，则 该来账指令存在待调账或已审核的记录不允许调账
-- 检验2、调账审核表，AuditStatus not in ('1', '4')  -- 待调账账户存在待审核或审核成功的核销记录不能调账
SELECT * FROM djjs_fund.cash_bill_order_imp t WHERE t.audit_status IN ('1', '4') AND t.cash_bill_serial_no = 'cashBillOrder.CashBillSerialNo'; 
-- #AuditStatus （1 待审核/2 审核中/3 审核失败/4 审核通过/5 审核不通过/6 审核通过，执行失败）
-- 校验3、校验入账对手方资金账户,该账户只能是外部贷方账户或者内部自有资金户，fund_account.accnt_flag!=1 入账的投资人资金账户不能是大账户的核算账户
-- 用投资人账号查投资人账户信息，且校验 调账的对手方账户必须是贷方的资金账户
-- *******************************数据校验 end
-- 存在问题，这里 manual_acct_order 表没有关联 cashBillOrder.CashBillSerialNo，找不到关联关系
-- "技术调账"调账处理，新增记账记录 新增人工记账指令
-- 一条人工记账指令数据，记录借贷数据
insert into djjs_fund.manual_acct_order AcctType=20 入金调账记账，ExternalTradeNo=inputDate+10位seq，AccountOrderType=1 人工记账，AuditStatus=1 复核通过，DebitAccount=借方 大账户记账账户，CreditAccount=贷方 投资人账户
/**#acctType 记账类型:1-一般记账,2-冻结记账,3-解冻记账,4-冻结扣划,5-技术调整,
  * 9-入金记账,10-出金记账,11-日终结算款处理记账,12-反冲记账,13-入金冲正记账,
  * 14-出金冲正记账,15-转账记账,16-日间结算款处理记账,17-单边账入金调整,18-单边账出金调整,
  * 19-交易资金划转,20-入金调账记账，25-手工入账调账记账，26-特殊记账，27-单边冻结扣划
*/
-- 记账：以 manual_acct_order 为数据来源，新增一条数据
-- #AccountOrderStatus 0/1/2 待处理/成功/失败
insert into djjs_fund.acct_order acctType=functionNo=20，ExternalTradeNo=manual_acct_order.ExternalTradeNo，AccountOrderStatus=0 待处理，AccountOrderNo=select to_char(sysdate, 'yyyymmdd') || lpad(seq_acct_order.nextval, 8, '0') from dual
-- 记账请求分录表 两条数据
insert into djjs_fund.acct_order_detail account_order_no=AccountOrderNo，fund_account=大账户记账账户/投资人账户
-- /**********************银行端发起的入金冲正，执行账务余额处理  交易所端发起的入金冲正不需要更新余额 start**********************************/
-- 更新账户余额(大账户记账账户/投资人账户) AccountBalance，大账户记账账户减钱，投资人账户加钱
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '大账户记账账户' for update; 
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = '投资人账户' for update; 
-- update 两个账号（大账户记账账户 Z20181026000012）的余额 ACCOUNT_BALANCE-=occurAmount，USABLE_BALANCE-=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance-#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance-#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- update 两个账号（投资人账户）的余额 ACCOUNT_BALANCE+=occurAmount，USABLE_BALANCE+=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance+#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance+#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 生成账务流水，账务余额处理，生成两条账务流水，拷贝 acct_order_detail 的属性
insert into djjs_fund.acct_serial AccountOrderNo，ExternalTradeNo=manual_acct_order.ExternalTradeNo，FromFunctionNo=20 入金调账记账，fund_account=大账户记账账户/投资人账户，OpenMemCode=出参与人账号
-- /**********************银行端发起的入金冲正，执行账务余额处理  交易所端发起的入金冲正不需要更新余额 end**********************************/
-- 更新记账请求指令状态
update djjs_fund.acct_order set AccountOrderStatus=1 where AccountOrderNo=acct_order.AccountOrderNo
-- 更新来账指令入账状态"已调账"
update djjs_fund.cash_bill_order cashBillOrder set cashInstate=4 已调账，fundAccount=投资人账户，MemCode=投资人参与人账号，AccountName=投资人户名 where CashBillSerialNo=cash_bill_order.CashBillSerialNo
-- /*****************************************************************************查到以下数据进行核销，自动核销 start****************************/
-- 根据来账指令中付款账户名，金额及调账资金账号查询待核销结算指令中付款账号、名称、资金一致的记录；settle_fund 的数据在inford的债券清算定时任务中就已经录入
select * from djjs_fund.settle_fund settleFund where PayerFundAccount=投资人账户 and SettDealStatus=1 待核销 and SettlementAmount=cashBillOrder.发生额 and PayChannelId=渠道行 and trim(s.cash_bill_serial_no) is null;
-- #SettDealStatus 0 未生效，1 待核销，2 付款未确认，3 付款已确认，4 已推送结算，5 处理成功，6 处理失败，7 已撤销，8 清算成功，9 清算失败
-- #cashInstate=0/1/2/3/4/5/6	未入账/入账中/待调账/调账中/已调账/已核销/已退回
-- cash_bill_order.CashBillSerialNo+settFund.SettleFundId 核销款项操作 （对“待调账”、“已入账”或“合并”的来账指令进行勾选结算款信息）
-- 1、校验： 
-- 只有待调账或已调账状态的来账指令才能核销 cash_bill_order.CashInState in ('2', '4')
-- if CashInState=2时，检验入账的待确认资金账户与汇出结算款付款方一致 cash_bill_order.WaitFundAccount（大账户记账账户）必须=settleFund.PayerFundAccount，else CashInState=4时，投资人的资金账户与汇出结算款付款方 cash_bill_order.FundAccount（投资人账户）必须=settleFund.PayerFundAccount
-- settleFund.SettDealStatus 必须='1' 待核销的才能核销
-- settleFund.CashBillSerialNo 必须是空的
-- 校验结算款金额 settleFund.settle_amount(指令金额加和) 要小于等于待核销金额 cash_bill_order.UnRevocationAmount
-- 校验 查询是否存在“未处理”或“处理成功”的核销款项	(来账指令已经核销过该结算款，请审核或更换核销款项)
SELECT * FROM cash_in_sett t where t.settle_fund_id = 'settleFundId' and DEAL_STATE in ('0','2'); 
-- dealState  DEAL_STATE
-- 110045:账务处理状态-0:待处理
-- 110045:账务处理状态-1:处理中
-- 110045:账务处理状态-2:处理成功
-- 110045:账务处理状态-3:处理失败
-- 110045:账务处理状态-4:已撤销
-- 2、插入审核状态为“待审核”的结算款信息（入账到入账审核表），拷贝 order 属性数据到 cash_bill_order_imp
insert into djjs_fund.cash_bill_order_imp auditStatus=1 待审核，RevocationAmount（已核销金额）=settleFund.settle_amount(指令金额加和)，UnRevocationAmount（未核销金额）=order.getOccurAmount().subtract(settle_amount)
insert into cash_in_sett CashBillSerialNo=cash_bill_order.CashBillSerialNo，DealState=0，SettleFundId=settFund.SettleFundId
------------------------------------------------------ 以上为待审核过程，以下为不审核直接通过过程
-- 3、更新来账指令为“核销待审核”,记录核销结果，未核销金额为0才推送结算
-- BigDecimal leftAmount=order.getUnRevocationAmount().subtract(settle_amount); 未核销金额=来账指令中的未核销金额-结算金额
-- if leftAmount=0，变更核销的结算款的来账指令和状态为“付款已确认” 
update  settleFund set SettDealStatus=2 付款未确认 where CashBillSerialNo;
-- 更新来账核销关系表状态为处理成功
update cash_in_sett set DealState=2;
-- 更新来账指令的核销金额和非核销金额
update cash_bill_order set CashInState=5 已核销; 
-- else 空
-- finally
update cash_bill_order set RevocationAmount+=settle_amount 已核销金额，UnRevocationAmount=leftAmount 未核销金额，Reserve1=settleFundIds
-- /*****************************************************************************查到以下数据进行核销，自动核销 end****************************/
-- 将所有查询流水结果插入银行账户明细表
insert into djjs_fund.bank_account_detail PayChannelId=渠道行，BankBillNo=银行流水号，TransDate, TransTime, PaycardName, PaycardNo=accountNo 付款方账号，ReceicardNo=OppAccountNo 对手方账号，金额单位是分
-- 出金更新银行流水号 BankBillNo
update djjs_fund.fund_bank_transfer set BankBillNo, TransStatus='2 成功 3 失败' where InnerBillNo='流水返回';
-- 更新出入金表的银行流水号
update djjs_fund.cash_exchange_detail set BankBillNo='银行流水号' where RelatedFundLogId=fund_bank_transfer.FundBillNo;

--------------------------------------------------------------- fund 查询银行流水，处理入金流水 0 0/15 * * * ? end---------------------------

--------------------------------------------------------------- fund 定时任务调用记账队列 0 0/1 * * * ? start---------------------------
SELECT * FROM djjs_fund.accounts_queue t where t.dealState=0;-- 查询数据进行处理，一次处理最大条数由数据库配置
update djjs_fund.accounts_queue set dealState=1 where settlementAccount='大账户结算账号';
-- 更新余额(大账户结算账户) AccountBalance，入金加钱
SELECT * FROM djjs_fund.account_balance t WHERE t.fund_account = 'Z20181026000004' for update; 
-- 更新发生额 ACCOUNT_BALANCE+=occurAmount，USABLE_BALANCE+=occurAmount，md5_result=(select djjs_fund.ap_fund_md5_utils( (t.account_balance+#{occurAmount,jdbcType=DECIMAL}) ||''|| (t.usable_balance+#{occurAmount,jdbcType=DECIMAL}) ||''||t.freeze_balance) from dual)
-- 返回值：AccountBalance.PreBalance=account_balance.AccountBalance, AccountBalance.AccountBalance=account_balance.AccountBalance+occurAmount(发生额)
-- 回执状态为成功，更新入金明细状态，并进行记账操作，入金记账 支付途径设置的核算账户（贷）和客户的资金账户（借）记账
-- 入金记账 9
insert into djjs_fund.acct_order acctType=functionNo=9 入金记账，ExternalTradeNo=出入金明细表.ExternalTradeNo，AccountOrderStatus=0 待处理，AccountOrderNo=select to_char(sysdate, 'yyyymmdd') || lpad(seq_acct_order.nextval, 8, '0') from dual
-- 记账请求分录表 两条数据
insert into djjs_fund.acct_order_detail account_order_no=AccountOrderNo，fund_account=大账户记账账户/大账户结算账户

-- 生成账务流水，账务余额处理，生成两条账务流水，拷贝 acct_order_detail 的属性
insert into djjs_fund.acct_serial AccountOrderNo，ExternalTradeNo=出入金明细表.ExternalTradeNo，FromFunctionNo=9 入金记账，fund_account=大账户记账账户/大账户结算账户，OpenMemCode=出参与人账号
-- 更新记账请求指令状态
update djjs_fund.acct_order set AccountOrderStatus=1 where AccountOrderNo=acct_order.AccountOrderNo



--------------------------------------------------------------- fund 定时任务调用记账队列 0 0/1 * * * ? end---------------------------
--------------------------------------------------------------- fund 查询银行流水，处理入金流水 end---------------------------









---------------------------------------------------定时quartz相关表-------------------------------------------------------
SELECT * FROM djjs_fund.qrtz_blob_triggers;
SELECT * FROM djjs_fund.qrtz_calendars;
SELECT * FROM djjs_fund.qrtz_cron_triggers;
SELECT * FROM djjs_fund.qrtz_fired_triggers;
SELECT * FROM djjs_fund.qrtz_job_details;
SELECT * FROM djjs_fund.qrtz_locks;
SELECT * FROM djjs_fund.qrtz_paused_trigger_grps;
SELECT * FROM djjs_fund.qrtz_scheduler_state;
SELECT * FROM djjs_fund.qrtz_simple_triggers;
SELECT * FROM djjs_fund.qrtz_simprop_triggers;
SELECT * FROM djjs_fund.qrtz_triggers;
---------------------------------------------------定时quartz相关表-------------------------------------------------------
