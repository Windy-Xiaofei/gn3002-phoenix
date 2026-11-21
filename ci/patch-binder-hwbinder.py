#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给 3.10 的 binder 驱动补上 /dev/hwbinder 和 /dev/vndbinder。

背景
----
Android 8.0 起 HIDL 走独立的 binder 域，对应三个设备节点：

    /dev/binder      framework <-> framework   （servicemanager）
    /dev/hwbinder    framework <-> vendor      （hwservicemanager）
    /dev/vndbinder   vendor    <-> vendor      （vndservicemanager）

三个域彼此隔离：各有自己的 context manager（handle 0）和对象表。

3.10 的 MTK binder 只注册了 /dev/binder，而且 binder_context_mgr_node
是**全局单例**，于是：

  - hwservicemanager 打开 /dev/hwbinder 直接 ENOENT，进程退出；连续 4 次
    后 init 判定 critical process 失败 -> panic -> 重启进 bootloader；
  - 就算把 /dev/hwbinder 软链到 /dev/binder 也没用：
    hwservicemanager 调 BINDER_SET_CONTEXT_MGR 会收到 EBUSY，
    因为 servicemanager 已经占了那个唯一位置。

改法
----
1. binder_proc 增加 binder_dev_name / ctx_mgr_node / ctx_mgr_uid；
2. binder_open 拆成 binder_open_common(nodp, filp, dev_name)，
   三个设备各一个薄壳把设备名传进去——不依赖任何全局 miscdevice 指针，
   也就没有声明顺序问题；
3. 新增 hwbinder_miscdev / vndbinder_miscdev，各有自己的 fops，
   除 .open 之外全部与 binder_fops 相同；
4. binder_ioctl_set_ctx_mgr 按设备分流：/dev/binder 继续用全局单例
   （servicemanager 行为不变），其余用 proc 自己的；
5. 两处读 context manager 的代码改成"先 proc 自己的，再回落全局"。

注意 C89：内核用 -std=gnu89，语句之后不能再声明变量。补丁里新增的量
全部放在声明区，或者干脆不引入新变量。

用法：
    python3 ci/patch-binder-hwbinder.py <kernel>/drivers/android/binder.c
"""
import sys


def sub(s, old, new, tag):
    if old not in s:
        sys.exit('没找到待替换片段(%s)，源码结构可能变了' % tag)
    print('  已替换:', tag)
    return s.replace(old, new, 1)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    p = sys.argv[1]
    s = open(p, encoding='utf-8', errors='replace').read()

    if 'hwbinder_miscdev' in s:
        print('已经打过补丁，跳过')
        return

    # ------------------------------------------------------------------
    # 1. binder_proc 增加字段
    # ------------------------------------------------------------------
    s = sub(s, '''	struct dentry *debugfs_entry;
#ifdef RT_PRIO_INHERIT''',
            '''	struct dentry *debugfs_entry;
	/* 这个 proc 从哪个 binder 设备打开：binder / hwbinder / vndbinder。
	 * 三个域的 context manager 必须各自独立，否则 hwservicemanager
	 * 注册时会撞上 servicemanager 已占用的全局位置。 */
	const char *binder_dev_name;
	struct binder_node *ctx_mgr_node;
	kuid_t ctx_mgr_uid;
#ifdef RT_PRIO_INHERIT''', 'binder_proc 增加 dev_name / ctx_mgr 字段')

    # ------------------------------------------------------------------
    # 2. binder_open 拆成公共实现 + 三个薄壳
    # ------------------------------------------------------------------
    s = sub(s, '''static int binder_open(struct inode *nodp, struct file *filp)
{
	struct binder_proc *proc;
''',
            '''/* 三个 binder 域共用这一份实现，只是设备名不同。
 * binder_open() 原本就不看 inode（状态全在 binder_proc 里），
 * 所以同一个 binder_fops 被多个 chrdev 共用是安全的。 */
static int binder_open_common(struct inode *nodp, struct file *filp,
			      const char *dev_name)
{
	struct binder_proc *proc;
''', 'binder_open 改成 binder_open_common')

    s = sub(s, '''	INIT_LIST_HEAD(&proc->delivered_death);
	filp->private_data = proc;''',
            '''	INIT_LIST_HEAD(&proc->delivered_death);

	proc->binder_dev_name = dev_name;
	proc->ctx_mgr_node = NULL;
	proc->ctx_mgr_uid = INVALID_UID;

	filp->private_data = proc;''', 'binder_open_common 记录设备名')

    # ------------------------------------------------------------------
    # 3. 三个 open 薄壳必须放在 binder_fops 之前（C 要先声明后使用）
    # ------------------------------------------------------------------
    s = sub(s, '''static const struct file_operations binder_fops = {''',
            '''/* binder_open 已改名为 binder_open_common，这里补回原名字的薄壳，
 * 下面的 binder_fops 定义就不用动。三个薄壳必须放在这里，
 * 因为 binder_fops 里要引用它们，C 要求先声明。 */
static int binder_open(struct inode *nodp, struct file *filp)
{
	return binder_open_common(nodp, filp, "binder");
}

static int hwbinder_open(struct inode *nodp, struct file *filp)
{
	return binder_open_common(nodp, filp, "hwbinder");
}

static int vndbinder_open(struct inode *nodp, struct file *filp)
{
	return binder_open_common(nodp, filp, "vndbinder");
}

static const struct file_operations binder_fops = {''', '三个 open 薄壳')

    # ------------------------------------------------------------------
    # 4. 新增两个 misc 设备 + 两个 fops
    # ------------------------------------------------------------------
    s = sub(s, '''static struct miscdevice binder_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "binder",
	.fops = &binder_fops
};''',
            '''/* 只有 .open 不同，其余全部复用 binder_fops 的实现。 */
static const struct file_operations hwbinder_fops = {
	.owner = THIS_MODULE,
	.poll = binder_poll,
	.unlocked_ioctl = binder_ioctl,
	.compat_ioctl = binder_ioctl,
	.mmap = binder_mmap,
	.open = hwbinder_open,
	.flush = binder_flush,
	.release = binder_release,
};

static const struct file_operations vndbinder_fops = {
	.owner = THIS_MODULE,
	.poll = binder_poll,
	.unlocked_ioctl = binder_ioctl,
	.compat_ioctl = binder_ioctl,
	.mmap = binder_mmap,
	.open = vndbinder_open,
	.flush = binder_flush,
	.release = binder_release,
};

static struct miscdevice binder_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "binder",
	.fops = &binder_fops
};

/* Android 8.0 的 HIDL 需要这两个域。内核里它们只是同一套驱动的
 * 另外两个 chrdev，隔离靠"每个 proc 自己的 ctx_mgr_node"实现。 */
static struct miscdevice hwbinder_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "hwbinder",
	.fops = &hwbinder_fops
};

static struct miscdevice vndbinder_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "vndbinder",
	.fops = &vndbinder_fops
};''', '新增 hwbinder / vndbinder 设备与 fops')

    # ------------------------------------------------------------------
    # 4. SET_CONTEXT_MGR 按设备分流
    # ------------------------------------------------------------------
    s = sub(s, '''    if (binder_context_mgr_node != NULL) {
        pr_err("BINDER_SET_CONTEXT_MGR already set\\n");
        ret = -EBUSY;
        goto out;
    }''',
            '''    /* /dev/binder 沿用全局单例（与 3.10 原行为完全一致），
     * hwbinder / vndbinder 使用各自 proc 上的字段。 */
    int primary = (strcmp(proc->binder_dev_name, "binder") == 0);

    if (primary) {
        if (binder_context_mgr_node != NULL) {
            pr_err("BINDER_SET_CONTEXT_MGR already set\\n");
            ret = -EBUSY;
            goto out;
        }
    } else {
        if (proc->ctx_mgr_node != NULL) {
            pr_err("BINDER_SET_CONTEXT_MGR already set on %s\\n",
                   proc->binder_dev_name);
            ret = -EBUSY;
            goto out;
        }
    }''', 'SET_CONTEXT_MGR 分流（前置检查）')

    s = sub(s, '''    if (uid_valid(binder_context_mgr_uid)) {
        if (!uid_eq(binder_context_mgr_uid, curr_euid)) {
            pr_err("BINDER_SET_CONTEXT_MGR bad uid %d != %d\\n",
                    from_kuid(&init_user_ns, curr_euid),
                    from_kuid(&init_user_ns,
                    binder_context_mgr_uid));
            ret = -EPERM;
            goto out;
        }
    } else {
        binder_context_mgr_uid = curr_euid;
    }
    binder_context_mgr_node = binder_new_node(proc, 0, 0);
    if (binder_context_mgr_node == NULL) {
        ret = -ENOMEM;
        goto out;
    }''',
            '''    if (primary) {
        if (uid_valid(binder_context_mgr_uid)) {
            if (!uid_eq(binder_context_mgr_uid, curr_euid)) {
                pr_err("BINDER_SET_CONTEXT_MGR bad uid %d != %d\\n",
                        from_kuid(&init_user_ns, curr_euid),
                        from_kuid(&init_user_ns,
                        binder_context_mgr_uid));
                ret = -EPERM;
                goto out;
            }
        } else {
            binder_context_mgr_uid = curr_euid;
        }
        binder_context_mgr_node = binder_new_node(proc, 0, 0);
        if (binder_context_mgr_node == NULL) {
            ret = -ENOMEM;
            goto out;
        }
    } else {
        if (uid_valid(proc->ctx_mgr_uid)) {
            if (!uid_eq(proc->ctx_mgr_uid, curr_euid)) {
                pr_err("BINDER_SET_CONTEXT_MGR bad uid %d != %d on %s\\n",
                        from_kuid(&init_user_ns, curr_euid),
                        from_kuid(&init_user_ns, proc->ctx_mgr_uid),
                        proc->binder_dev_name);
                ret = -EPERM;
                goto out;
            }
        } else {
            proc->ctx_mgr_uid = curr_euid;
        }
        proc->ctx_mgr_node = binder_new_node(proc, 0, 0);
        if (proc->ctx_mgr_node == NULL) {
            ret = -ENOMEM;
            goto out;
        }
    }''', 'SET_CONTEXT_MGR 分流（创建节点）')

    s = sub(s, '''#ifdef BINDER_MONITOR
    strcpy(binder_context_mgr_node->name, "servicemanager");
    pr_debug("%d:%d set as servicemanager uid %d\\n",
            proc->pid, thread->pid, binder_context_mgr_uid);
#endif
    binder_context_mgr_node->local_weak_refs++;
    binder_context_mgr_node->local_strong_refs++;
    binder_context_mgr_node->has_strong_ref = 1;
    binder_context_mgr_node->has_weak_ref = 1;''',
            '''    {
        /* C89：变量声明必须放在块的头部。 */
        struct binder_node *mgr = primary ? binder_context_mgr_node
                                          : proc->ctx_mgr_node;
#ifdef BINDER_MONITOR
        strcpy(mgr->name, primary ? "servicemanager" : proc->binder_dev_name);
        pr_debug("%d:%d set as %s uid %d\\n", proc->pid, thread->pid,
                 mgr->name,
                 from_kuid(&init_user_ns,
                           primary ? binder_context_mgr_uid
                                   : proc->ctx_mgr_uid));
#endif
        mgr->local_weak_refs++;
        mgr->local_strong_refs++;
        mgr->has_strong_ref = 1;
        mgr->has_weak_ref = 1;
    }''', 'SET_CONTEXT_MGR 分流（引用计数）')

    # ------------------------------------------------------------------
    # 5. 读 context manager：先 proc 自己的，再回落全局
    #     不引入新变量，避开 C89 混用声明与语句
    # ------------------------------------------------------------------
    s = sub(s, '''			target_node = binder_context_mgr_node;
			if (target_node == NULL) {''',
            '''			/* 每个 binder 域有自己的 handle 0。优先用本 proc 的，
			 * 没有再回落到全局（/dev/binder 的老路径）。 */
			target_node = proc->ctx_mgr_node
					? proc->ctx_mgr_node
					: binder_context_mgr_node;
			if (target_node == NULL) {''', '读取 handle 0')

    s = sub(s, '''			if (target == 0 && binder_context_mgr_node &&
			    (cmd == BC_INCREFS || cmd == BC_ACQUIRE)) {
				ref = binder_get_ref_for_node(proc,
					       binder_context_mgr_node);''',
            '''			if (target == 0 &&
			    (proc->ctx_mgr_node || binder_context_mgr_node) &&
			    (cmd == BC_INCREFS || cmd == BC_ACQUIRE)) {
				ref = binder_get_ref_for_node(proc,
					       proc->ctx_mgr_node
					       ? proc->ctx_mgr_node
					       : binder_context_mgr_node);''',
            '引用递增到 handle 0')

    # ------------------------------------------------------------------
    # 6. 注册新设备
    # ------------------------------------------------------------------
    s = sub(s, '''	ret = misc_register(&binder_miscdev);
	if (binder_debugfs_dir_entry_root) {''',
            '''	ret = misc_register(&binder_miscdev);
	if (ret)
		return ret;

	/* Android 8.0 的 HIDL 依赖这两个域。任一失败只告警，
	 * 不能连带让 /dev/binder 也起不来。 */
	ret = misc_register(&hwbinder_miscdev);
	if (ret)
		pr_err("binder: failed to register hwbinder: %d\\n", ret);
	else
		pr_info("binder: /dev/hwbinder registered\\n");

	ret = misc_register(&vndbinder_miscdev);
	if (ret)
		pr_err("binder: failed to register vndbinder: %d\\n", ret);
	else
		pr_info("binder: /dev/vndbinder registered\\n");

	ret = 0;
	if (binder_debugfs_dir_entry_root) {''', '注册 hwbinder / vndbinder')

    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print('完成: binder.c 已支持 hwbinder / vndbinder')


if __name__ == '__main__':
    main()
