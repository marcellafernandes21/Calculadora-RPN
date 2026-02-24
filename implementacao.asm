.data
    prompt:         .asciiz "Digite a expressao em notacao polonesa reversa (RPN): "
    mensagem_resultado:  .asciiz "Resultado: "
    mensagem_erro_pilha_vazia: .asciiz "Erro: pilha vazia.\n"
    mensagem_erro_div_zero:  .asciiz "Erro: Divisao por zero.\n"
    mensagem_erro_expr_invalida: .asciiz "Erro: Expressao invalida.\n"
    buffer:         .space 100
.text
.globl main
main:
    # Imprimir prompt
    li $v0, 4
    la $a0, prompt
    syscall
    # Ler expressao
    li $v0, 8
    la $a0, buffer
    li $a1, 100
    syscall
    # Remover nova linha
    la $t0, buffer
remover_nova_linha:
    lb $t1, ($t0)
    beq $t1, 10, substituir_nulo   # 10 eh o codigo ASCII para \n
    beqz $t1, substituir_nulo      # Verifica fim da string
    addiu $t0, $t0, 1
    j remover_nova_linha
substituir_nulo:
    sb $zero, ($t0)
    # Chamar calculadoraRPN
    la $a0, buffer
    jal calculadora_rpn
    # Imprimir resultado
    move $t0, $v0
    li $v0, 4
    la $a0, mensagem_resultado
    syscall
    li $v0, 1
    move $a0, $t0
    syscall
    # Sair
    li $v0, 10
    syscall
calculadora_rpn:
    # Inicializar pilha
    move $t0, $a0  # $t0 = expressao
    li $t1, 0      # $t1 = topo da pilha
    # Tokenizar expressao
loop_principal:
    lb $t2, ($t0)
    beqz $t2, fim_loop
    # Ignorar espacos
    beq $t2, 32, proximo    # 32 eh o codigo ASCII para espaco
    # Verificar se e um operador
    beq $t2, 43, processar_operador    # + (43)
    beq $t2, 45, verificar_menos   # - (45) - pode ser operador ou numero negativo
    beq $t2, 42, processar_operador    # * (42)
    beq $t2, 47, processar_operador    # / (47)
    # Se nao for operador, deve ser um numero
    j iniciar_verificacao_digito
verificar_menos:
    # Verifica se o proximo caractere apos o - eh um digito (numero negativo)
    addiu $t5, $t0, 1
    lb $t6, ($t5)
    blt $t6, 48, processar_operador    # Se nao for digito, e operador -
    bgt $t6, 57, processar_operador    # Se nao for digito, e operador -
    # E um numero negativo, continua com o processamento de numero
iniciar_verificacao_digito:
    li $t3, 0      # $t3 = valor numerico
    li $t4, 1      # $t4 = sinal (1 para positivo, -1 para negativo)
    # Verificar se comeca com - (negativo)
    beq $t2, 45, definir_negativo
    j processar_digito
definir_negativo:
    li $t4, -1
    addiu $t0, $t0, 1
    lb $t2, ($t0)
processar_digito:
    # Verifica se e digito
    blt $t2, 48, erro_expressao_invalida    # < '0'
    bgt $t2, 57, erro_expressao_invalida    # > '9'
loop_digito:
    # Converte ASCII para inteiro
    sub $t5, $t2, 48
    mul $t3, $t3, 10
    add $t3, $t3, $t5
    # Proximo caractere
    addiu $t0, $t0, 1
    lb $t2, ($t0)
    beqz $t2, empilhar_numero    # Fim da string
    beq $t2, 32, empilhar_numero    # Espaco
    blt $t2, 48, verificar_empilhar_numero    # Nao e digito
    bgt $t2, 57, verificar_empilhar_numero    # Nao e digito
    j loop_digito
verificar_empilhar_numero:
    # Verifica se e um operador valido apos o numero
    beq $t2, 43, empilhar_numero    # +
    beq $t2, 45, empilhar_numero    # -
    beq $t2, 42, empilhar_numero    # *
    beq $t2, 47, empilhar_numero    # /
    j erro_expressao_invalida
empilhar_numero:
    # Aplica o sinal e coloca na pilha
    mul $t3, $t3, $t4
    # Push para a pilha
    addiu $sp, $sp, -4
    sw $t3, ($sp)
    addiu $t1, $t1, 1
    # Se estamos no fim ou espaco, continua
    beqz $t2, fim_loop
    beq $t2, 32, proximo
    # Se for operador, processa
    j verificar_operador
processar_operador:
    # Verificar se tem pelo menos 2 operandos na pilha
    blt $t1, 2, erro_pilha_vazia
    # Pop dois operandos
    lw $t6, ($sp)  # segundo operando
    addiu $sp, $sp, 4
    addiu $t1, $t1, -1
    lw $t7, ($sp)  # primeiro operando
    addiu $sp, $sp, 4
    addiu $t1, $t1, -1
    # Realizar operacao
verificar_operador:
    beq $t2, 43, operacao_soma        # +
    beq $t2, 45, operacao_subtracao   # -
    beq $t2, 42, operacao_multiplicacao  # *
    beq $t2, 47, operacao_divisao     # /
operacao_soma:
    add $t8, $t7, $t6
    j empilhar_resultado
operacao_subtracao:
    sub $t8, $t7, $t6
    j empilhar_resultado
operacao_multiplicacao:
    mul $t8, $t7, $t6
    j empilhar_resultado
operacao_divisao:
    beqz $t6, erro_divisao_zero
    div $t7, $t6
    mflo $t8
empilhar_resultado:
    # Push resultado para a pilha
    addiu $sp, $sp, -4
    sw $t8, ($sp)
    addiu $t1, $t1, 1
proximo:
    addiu $t0, $t0, 1
    j loop_principal
fim_loop:
    # Verificar se temos exatamente um valor na pilha
    bne $t1, 1, erro_expressao_invalida
    # Pop resultado final
    lw $v0, ($sp)
    addiu $sp, $sp, 4
    jr $ra
erro_pilha_vazia:
    li $v0, 4
    la $a0, mensagem_erro_pilha_vazia
    syscall
    li $v0, 10
    syscall
erro_divisao_zero:
    li $v0, 4
    la $a0, mensagem_erro_div_zero
    syscall
    li $v0, 10
    syscall
erro_expressao_invalida:
    li $v0, 4
    la $a0, mensagem_erro_expr_invalida
    syscall
    li $v0, 10
    syscall